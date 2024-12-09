const express = require("express");
const bcrypt = require("bcrypt");
const oracledb = require("oracledb");
const jwt = require("jsonwebtoken");
const bodyParser = require("body-parser");
const cors = require("cors");
const Client = require("ssh2").Client;
const net = require("net");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(bodyParser.json());
app.use((req, res, next) => {
  console.log(`API 요청: ${req.originalUrl}`);
  next();
});

const { DB_USER, DB_PASSWORD, DB_CONNECT_STRING, SSH_HOST, SSH_PORT, SSH_USER, SSH_PASSWORD } = process.env;

function createSSHTunnel() {
  return new Promise((resolve, reject) => {
    const conn = new Client();

    conn.on("ready", () => {
      // Parse original connection string
      const [host, sid] = DB_CONNECT_STRING.split("/");
      const [dbHost, dbPort] = host.split(":");

      conn.forwardOut(
        "127.0.0.1", // sourceIP
        0, // sourcePort
        dbHost, // destinationIP
        parseInt(dbPort), // destinationPort
        (err, stream) => {
          if (err) {
            conn.end();
            return reject(err);
          }

          // Find an available local port
          const localServer = net.createServer((socket) => {
            stream.pipe(socket).pipe(stream);
          });

          localServer.listen(0, () => {
            const localPort = localServer.address().port;

            resolve({
              connection: conn,
              localServer,
              localPort,
              sid,
            });
          });
        }
      );
    });

    conn.on("error", (err) => {
      reject(err);
    });

    // Connect to SSH server
    conn.connect({
      host: SSH_HOST,
      port: SSH_PORT,
      username: SSH_USER,
      password: SSH_PASSWORD,
    });
  });
}

async function connectDatabase() {
  const tunnel = await createSSHTunnel();

  const dbConfig = {
    user: DB_USER,
    password: DB_PASSWORD,
    connectString: `localhost:${tunnel.localPort}/${tunnel.sid}`,
  };

  const connection = await oracledb.getConnection(dbConfig);

  return { connection, tunnel };
}

app.post("/company/login", async (req, res) => {
  const { AUTH_ID, password } = req.body;
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute(`SELECT AUTH_ID, PW_HASH FROM COMPANY_AUTH WHERE AUTH_ID = :AUTH_ID`, [
      AUTH_ID,
    ]);

    if (result.rows.length === 0) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const [userId, hashedPassword] = result.rows[0];
    const isPasswordValid = await bcrypt.compare(password, hashedPassword);

    if (isPasswordValid) {
      res.status(200).json({ message: "Login successful" });
    } else {
      res.status(401).json({ error: "Invalid credentials" });
    }

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();
  } catch (error) {
    console.error("Error logging in:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Login failed" });
  }
});

app.get("/company/expiration", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute(
      `SELECT
    S.SUBSCRIPTION_ID,
    S.SUBSCRIPTION_YEAR,
    S.DATE_CREATED,
    S.BEGIN_DATE,
    ADD_MONTHS(S.BEGIN_DATE, S.SUBSCRIPTION_YEAR * 12) AS EXPIRED_DATE,
    S.CUSTOMER_ID,
    S.SERIAL_NUMBER  
FROM
    SUBSCRIPTION S
WHERE
    ADD_MONTHS(S.BEGIN_DATE, S.SUBSCRIPTION_YEAR * 12) < SYSDATE
    AND NOT EXISTS (
        SELECT 1
        FROM REQUEST R
        WHERE R.SUBSCRIPTION_ID = S.SUBSCRIPTION_ID
        AND R.REQUEST_TYPE = '회수'
    )
ORDER BY
    EXPIRED_DATE ASC`
    );

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    const subscriptions = result.rows.map((row) => {
      const subscription = {
        SUBSCRIPTION_ID: row[0],
        SUBSCRIPTION_YEAR: row[1],
        DATE_CREATED: row[2] ? row[2].toISOString() : new Date().toISOString(),
        BEGIN_DATE: row[3] ? row[3].toISOString() : null,
        EXPIRED_DATE: row[4] ? row[4].toISOString() : null,
        CUSTOMER_ID: row[5],
        SERIAL_NUMBER: row[6],
      };
      return subscription;
    });
    if (subscriptions.length === 0) {
      return res.json([]);
    }
    res.json(subscriptions);
  } catch (error) {
    console.error("Error fetching expired subscriptions:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get expired subscriptions" });
  }
});

app.post("/company/expiration/return", async (req, res) => {
  const { subscriptionId, visitDate } = req.body;
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    await connection.execute("SET TRANSACTION READ WRITE");

    const requestResult = await connection.execute(
      "INSERT INTO REQUEST (REQUEST_ID, REQUEST_TYPE, REQUEST_STATUS, DATE_CREATED, SUBSCRIPTION_ID) VALUES (R_SEQ.NEXTVAL, '회수', '대기중', SYSDATE, :subscriptionId)",
      [subscriptionId]
    );

    await connection.execute(
      "INSERT INTO REQUEST_PREFERENCE_DATE (PREFERENCE_ID, PREFER_DATE, REQUEST_ID) VALUES (RPD_SEQ.NEXTVAL, TO_DATE(:preferDate, 'YYYY-MM-DD HH24:MI:SS'), R_SEQ.CURRVAL)",
      [visitDate]
    );

    await connection.commit();
    res.status(200).json({ message: "created successfully", subscriptionId });

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();
  } catch (error) {
    if (dbConnection) {
      await dbConnection.rollback();
      await dbConnection.close();
    }

    if (sshTunnel) {
      sshTunnel.connection.end();
      sshTunnel.localServer.close();
    }

    console.error("Error creating:", error);
    res.status(500).json({ error: "Failed to create" });
  }
});

app.post("/company/expiration/extend", async (req, res) => {
  const { subscriptionId, addSubscriptionYear } = req.body;
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    await connection.execute("SET TRANSACTION READ WRITE");

    const expiredDateResult = await connection.execute(
      "SELECT SUBSCRIPTION_YEAR FROM SUBSCRIPTION WHERE SUBSCRIPTION_ID = :subscriptionId",
      [subscriptionId]
    );

    if (expiredDateResult.rows.length === 0) {
      return res.status(404).json({ error: "Subscription not found" });
    }

    const [prevSubscriptionYear] = expiredDateResult.rows[0];
    const afterSubscriptionYear = prevSubscriptionYear + addSubscriptionYear;

    await connection.execute(
      `
      UPDATE SUBSCRIPTION 
      SET SUBSCRIPTION_YEAR = :afterSubscriptionYear         
      WHERE SUBSCRIPTION_ID = :subscriptionId
      `,
      {
        afterSubscriptionYear,
        subscriptionId,
      }
    );

    await connection.commit();
    res.status(200).json({ message: "Subscription extended successfully", subscriptionId });

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();
  } catch (error) {
    if (dbConnection) {
      await dbConnection.rollback();
      await dbConnection.close();
    }

    if (sshTunnel) {
      sshTunnel.connection.end();
      sshTunnel.localServer.close();
    }

    console.error("Error extending subscription:", error);
    res.status(500).json({ error: "Failed to extend subscription" });
  }
});

app.get("/company/subscription", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute(
      `SELECT
        S.SUBSCRIPTION_ID,
        S.SUBSCRIPTION_YEAR,
        S.DATE_CREATED,
        S.BEGIN_DATE,
        ADD_MONTHS(S.BEGIN_DATE, S.SUBSCRIPTION_YEAR * 12) AS EXPIRED_DATE,
        S.CUSTOMER_ID,
        S.SERIAL_NUMBER
      FROM
        SUBSCRIPTION S
      WHERE S.SERIAL_NUMBER IN (SELECT SERIAL_NUMBER FROM PRODUCT WHERE PRODUCT_STATUS = '구독중')
      ORDER BY
        DATE_CREATED DESC`
    );

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    const subscriptions = result.rows.map((row) => {
      const subscription = {
        SUBSCRIPTION_ID: row[0],
        SUBSCRIPTION_YEAR: row[1],
        DATE_CREATED: row[2] ? row[2].toISOString() : new Date().toISOString(),
        BEGIN_DATE: row[3] ? row[3].toISOString() : null,
        EXPIRED_DATE: row[4] ? row[4].toISOString() : null,
        CUSTOMER_ID: row[5],
        SERIAL_NUMBER: row[6],
      };
      return subscription;
    });
    res.json(subscriptions);
  } catch (error) {
    console.error("Error fetching subscriptions:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get subscriptions" });
  }
});

app.get("/company/customers", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute(
      `SELECT CUSTOMER.CUSTOMER_ID, 
              CUSTOMER.CUSTOMER_NAME, 
              CUSTOMER.MAIN_PHONE_NUMBER, 
              CUSTOMER.SUB_PHONE_NUMBER, 
              CA.STREET_ADDRESS, 
              CA.DETAILED_ADDRESS 
       FROM CUSTOMER 
       JOIN CUSTOMER_ADDRESS CA ON CUSTOMER.CUSTOMER_ID = CA.CUSTOMER_ID ORDER BY CUSTOMER.CUSTOMER_ID`
    );

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "No customers found" });
    }

    const customers = result.rows.map((row) => ({
      CUSTOMER_ID: row[0],
      CUSTOMER_NAME: row[1],
      MAIN_PHONE_NUMBER: row[2],
      SUB_PHONE_NUMBER: row[3] || "없음",
      STREET_ADDRESS: row[4],
      DETAILED_ADDRESS: row[5],
    }));

    res.json(customers);
  } catch (error) {
    console.error("Error fetching customers:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get customers" });
  }
});

app.post("/customer/login", async (req, res) => {
  const { AUTH_ID, password } = req.body;
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute(`SELECT AUTH_ID, PW_HASH FROM CUSTOMER_AUTH WHERE AUTH_ID = :AUTH_ID`, [
      AUTH_ID,
    ]);

    if (result.rows.length === 0) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const [userAuthId, hashedPassword] = result.rows[0];
    const isPasswordValid = await bcrypt.compare(password, hashedPassword);

    if (!isPasswordValid) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const customerIdResult = await connection.execute(
      `SELECT CUSTOMER_ID FROM CUSTOMER_AUTH WHERE AUTH_ID = :AUTH_ID`,
      [AUTH_ID]
    );

    if (customerIdResult.rows.length === 0) {
      return res.status(404).json({ error: "Customer not found" });
    }

    const [customerId] = customerIdResult.rows[0];

    res.status(200).json({
      message: "Login successful",
      customerId: customerId,
    });

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();
  } catch (error) {
    console.error("Error logging in:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Login failed" });
  }
});

app.post("/customer/signup", async (req, res) => {
  const { customerName, authId, pw, mainPhoneNumber, subPhoneNumber, streetAddress, detailedAddress, postalCode } =
    req.body;
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    await connection.execute("SET TRANSACTION READ WRITE");
    const hashedPassword = await bcrypt.hash(pw, 12);
    await connection.execute(
      `INSERT INTO CUSTOMER (CUSTOMER_ID, CUSTOMER_NAME, MAIN_PHONE_NUMBER, SUB_PHONE_NUMBER, DATE_CREATED)
      VALUES (C_SEQ.NEXTVAL, :customerName, :mainPhoneNumber, :subPhoneNumber, SYSDATE)`,
      [customerName, mainPhoneNumber, subPhoneNumber]
    );
    await connection.execute(
      `INSERT INTO CUSTOMER_ADDRESS (CUSTOMER_ID, STREET_ADDRESS, DETAILED_ADDRESS, POSTAL_CODE)
      VALUES (C_SEQ.CURRVAL, :streetAddress, :detailedAddress, :postalCode)`,
      [streetAddress, detailedAddress, postalCode]
    );
    await connection.execute(
      `INSERT INTO CUSTOMER_AUTH (AUTH_ID, PW_HASH, CUSTOMER_ID)
      VALUES (:authId, :hashedPassword, C_SEQ.CURRVAL)`,
      [authId, hashedPassword]
    );
    await connection.commit();
    res.status(200).json({ message: "Customer created successfully" });

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();
  } catch (error) {
    if (dbConnection) {
      try {
        await dbConnection.rollback();
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    console.error("Error creating customer:", error);
    res.status(500).json({ error: "Failed to create customer" });
  }
});

app.post("/customer/signup/check", async (req, res) => {
  const { AUTH_ID } = req.body;
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute(`SELECT AUTH_ID FROM CUSTOMER_AUTH WHERE AUTH_ID = :AUTH_ID`, [AUTH_ID]);

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.status(200).json({ message: "Available" });
    } else {
      return res.status(409).json({ error: "Already exists" });
    }
  } catch (error) {
    console.error("Error checking AUTH_ID:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to check" });
  }
});

app.get("/customer/info/subscription/:customerId", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { customerId } = req.params;
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute(
      `SELECT DISTINCT S.SUBSCRIPTION_ID, 
                S.SUBSCRIPTION_YEAR, 
                S.DATE_CREATED, 
                S.BEGIN_DATE, 
                ADD_MONTHS(S.BEGIN_DATE, S.SUBSCRIPTION_YEAR * 12) AS EXPIRED_DATE, 
                S.CUSTOMER_ID, 
                S.SERIAL_NUMBER       
FROM SUBSCRIPTION S
JOIN REQUEST R ON S.SUBSCRIPTION_ID = R.SUBSCRIPTION_ID
WHERE S.CUSTOMER_ID = :customerId
  AND R.REQUEST_TYPE = '설치'
  AND R.REQUEST_STATUS = '방문완료'
`,
      [customerId]
    );

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.json([]);
    }

    const subscriptions = result.rows.map((row) => {
      const subscription = {
        SUBSCRIPTION_ID: row[0],
        SUBSCRIPTION_YEAR: row[1],
        DATE_CREATED: row[2] ? row[2].toISOString() : new Date().toISOString(),
        BEGIN_DATE: row[3] ? row[3].toISOString() : null,
        EXPIRED_DATE: row[4] ? row[4].toISOString() : null,
        CUSTOMER_ID: row[5],
        SERIAL_NUMBER: row[6],
      };
      return subscription;
    });

    res.json(subscriptions);
  } catch (error) {
    console.error("Error fetching subscriptions:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get subscriptions" });
  }
});

app.get("/customer/info/request/:customerId", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { customerId } = req.params;
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute(
      `SELECT 
          R.REQUEST_ID, 
          R.REQUEST_TYPE, 
          R.REQUEST_STATUS, 
          R.ADDITIONAL_COMMENT, 
          R.DATE_CREATED, 
          R.DATE_EDITED, 
          R.SUBSCRIPTION_ID,
          CASE 
            WHEN NOT EXISTS (
              SELECT 1
              FROM VISIT V
              WHERE V.REQUEST_ID = R.REQUEST_ID
            ) THEN (
              SELECT LISTAGG(TO_CHAR(PREFER_DATE, 'YY.MM.DD HH24:MI'), ', ') 
              WITHIN GROUP (ORDER BY PREFER_DATE)
              FROM REQUEST_PREFERENCE_DATE RP
              WHERE RP.REQUEST_ID = R.REQUEST_ID
            )
            ELSE TO_CHAR(
              (SELECT VISIT_DATE 
               FROM VISIT V 
               WHERE V.REQUEST_ID = R.REQUEST_ID 
               AND ROWNUM = 1), 'YY.MM.DD HH24:MI')
          END AS VISIT_DATE
       FROM REQUEST R
       WHERE R.SUBSCRIPTION_ID IN (
         SELECT S.SUBSCRIPTION_ID
         FROM SUBSCRIPTION S
         WHERE S.CUSTOMER_ID = :customerId
       )
       ORDER BY R.DATE_CREATED DESC`,
      [customerId]
    );

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.json([]);
    }

    const requests = result.rows.map((row) => {
      const request = {
        REQUEST_ID: row[0],
        REQUEST_TYPE: row[1] || "Unknown",
        REQUEST_STATUS: row[2] || "Unknown",
        ADDITIONAL_COMMENT: row[3] || null,
        DATE_CREATED: row[4] ? row[4].toISOString() : new Date().toISOString(),
        DATE_EDITED: row[5] ? row[5].toISOString() : null,
        SUBSCRIPTION_ID: row[6],
        VISIT_DATE: row[7],
      };
      return request;
    });

    res.json(requests);
  } catch (error) {
    console.error("Error fetching requests:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get requests" });
  }
});

app.post("/customer/info/request/cancel", async (req, res) => {
  const { requestId } = req.body;
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    await connection.execute("SET TRANSACTION READ WRITE");

    const requestTypeResult = await connection.execute(
      "SELECT REQUEST_TYPE FROM REQUEST WHERE REQUEST_ID = :requestId",
      { requestId }
    );

    if (requestTypeResult.rows.length === 0) {
      throw new Error("Request ID not found");
    }

    const requestType = requestTypeResult.rows[0][0];

    if (requestType === "설치") {
      const subscriptionIdResult = await connection.execute(
        "SELECT SUBSCRIPTION_ID FROM REQUEST WHERE REQUEST_ID = :requestId",
        { requestId }
      );

      if (subscriptionIdResult.rows.length === 0) {
        throw new Error("Subscription ID not found");
      }

      const subscriptionId = subscriptionIdResult.rows[0][0];

      const serialNumberResult = await connection.execute(
        "SELECT SERIAL_NUMBER FROM SUBSCRIPTION WHERE SUBSCRIPTION_ID = :subscriptionId",
        { subscriptionId }
      );

      if (serialNumberResult.rows.length === 0) {
        throw new Error("Serial number not found");
      }

      const serialNumber = serialNumberResult.rows[0][0];

      await connection.execute("UPDATE PRODUCT SET PRODUCT_STATUS = '재고' WHERE SERIAL_NUMBER = :serialNumber", {
        serialNumber,
      });

      await connection.execute("DELETE FROM REQUEST_PREFERENCE_DATE WHERE REQUEST_ID = :requestId", { requestId });
      await connection.execute("DELETE FROM REQUEST WHERE REQUEST_ID = :requestId", { requestId });
      await connection.execute("DELETE FROM SUBSCRIPTION WHERE SUBSCRIPTION_ID = :subscriptionId", { subscriptionId });
    } else {
      await connection.execute("DELETE FROM REQUEST_PREFERENCE_DATE WHERE REQUEST_ID = :requestId", { requestId });
      await connection.execute("DELETE FROM REQUEST WHERE REQUEST_ID = :requestId", { requestId });
    }

    await connection.commit();
    res.status(200).json({ message: "Request cancelled successfully" });

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();
  } catch (error) {
    if (dbConnection) {
      try {
        await dbConnection.rollback();
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to cancel request" });
  }
});

app.post("/customer/info/request/repair", async (req, res) => {
  const { subscriptionId, additionalComment, visitDate1, visitDate2 } = req.body;
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    await connection.execute("SET TRANSACTION READ WRITE");

    await connection.execute(
      `INSERT INTO REQUEST (REQUEST_ID, REQUEST_TYPE, REQUEST_STATUS, ADDITIONAL_COMMENT, DATE_CREATED, SUBSCRIPTION_ID) 
      VALUES (R_SEQ.NEXTVAL, '고장', '대기중', :additionalComment, SYSDATE, :subscriptionId)`,
      { additionalComment, subscriptionId }
    );

    await connection.execute(
      "INSERT INTO REQUEST_PREFERENCE_DATE (PREFERENCE_ID, PREFER_DATE, REQUEST_ID) VALUES (RPD_SEQ.NEXTVAL, TO_DATE(:prefer_date, 'YYYY-MM-DD HH24:MI'), R_SEQ.CURRVAL)",
      { prefer_date: visitDate1 }
    );

    await connection.execute(
      "INSERT INTO REQUEST_PREFERENCE_DATE (PREFERENCE_ID, PREFER_DATE, REQUEST_ID) VALUES (RPD_SEQ.NEXTVAL, TO_DATE(:prefer_date, 'YYYY-MM-DD HH24:MI'), R_SEQ.CURRVAL)",
      { prefer_date: visitDate2 }
    );

    await connection.commit();
    res.status(200).json({ message: "Repair request created successfully" });

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();
  } catch (error) {
    if (dbConnection) {
      await dbConnection.rollback();
      await dbConnection.close();
    }

    if (sshTunnel) {
      sshTunnel.connection.end();
      sshTunnel.localServer.close();
    }

    console.error("Error creating repair request:", error);
    res.status(500).json({ error: "Failed to create repair request" });
  }
});

app.get("/customer/model", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute("SELECT * FROM MODEL ORDER BY MODEL_TYPE ASC");

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "No models found" });
    }

    const models = result.rows.map((row) => {
      const model = {
        MODEL_ID: row[0],
        MODEL_NAME: row[1] || "Unknown",
        MODEL_TYPE: row[2] || "Unknown",
        YEARLY_FEE: row[3] || "Unknown",
        MANUFACTURER: row[4] || "Unknown",
        COLOR: row[5] || "Unknown",
        ENERGY_RATING: row[6] || "Unknown",
        RELEASE_YEAR: row[7] || "Unknown",
      };
      return model;
    });

    res.json(models);
  } catch (error) {
    console.error("Error fetching models:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get models" });
  }
});

app.post("/customer/model/subscribe", async (req, res) => {
  const { customerId, modelId, subscriptionYears, comment, visitDate1, visitDate2 } = req.body;
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    // 트랜잭션 시작
    await connection.execute("SET TRANSACTION READ WRITE");

    // 재고 있는 제품 조회
    const productResult = await connection.execute(
      "SELECT SERIAL_NUMBER FROM PRODUCT WHERE MODEL_ID = :model_id AND PRODUCT_STATUS = '재고' AND ROWNUM = 1",
      [modelId]
    );

    if (productResult.rows.length === 0) {
      return res.status(404).json({ error: "No stock available for the selected model" });
    }

    const serialNumber = productResult.rows[0][0];

    // 제품 상태 업데이트 ('재고' -> '구독대기')
    await connection.execute("UPDATE PRODUCT SET PRODUCT_STATUS = '구독대기' WHERE SERIAL_NUMBER = :serial_number", [
      serialNumber,
    ]);

    // SUBSCRIPTION 테이블에 데이터 삽입
    const subscriptionResult = await connection.execute(
      "INSERT INTO SUBSCRIPTION (SUBSCRIPTION_ID, SUBSCRIPTION_YEAR, DATE_CREATED, CUSTOMER_ID, SERIAL_NUMBER) VALUES (S_SEQ.NEXTVAL, :subscription_year, SYSDATE, :customer_id, :serial_number)",
      [subscriptionYears, customerId, serialNumber]
    );

    // SUBSCRIPTION_ID 가져오기
    const subscriptionIdResult = await connection.execute("SELECT S_SEQ.CURRVAL AS LAST_SUBSCRIPTION_ID FROM DUAL");
    const subscriptionId = subscriptionIdResult.rows[0][0];

    // REQUEST 테이블에 데이터 삽입
    await connection.execute(
      "INSERT INTO REQUEST (REQUEST_ID, REQUEST_TYPE, REQUEST_STATUS, ADDITIONAL_COMMENT, DATE_CREATED, SUBSCRIPTION_ID) VALUES (R_SEQ.NEXTVAL, '설치', '대기중', :additional_comment, SYSDATE, :subscription_id)",
      [comment, subscriptionId]
    );

    // REQUEST_ID 가져오기
    const requestIdResult = await connection.execute("SELECT R_SEQ.CURRVAL AS LAST_REQUEST_ID FROM DUAL");
    const requestId = requestIdResult.rows[0][0];

    // REQUEST_PREFERENCE_DATE 테이블에 선호 방문 일자 삽입
    await connection.execute(
      "INSERT INTO REQUEST_PREFERENCE_DATE (PREFERENCE_ID, PREFER_DATE, REQUEST_ID) VALUES (RPD_SEQ.NEXTVAL, TO_DATE(:prefer_date, 'YYYY-MM-DD HH24:MI'), :request_id)",
      [visitDate1, requestId]
    );

    await connection.execute(
      "INSERT INTO REQUEST_PREFERENCE_DATE (PREFERENCE_ID, PREFER_DATE, REQUEST_ID) VALUES (RPD_SEQ.NEXTVAL, TO_DATE(:prefer_date, 'YYYY-MM-DD HH24:MI'), :request_id)",
      [visitDate2, requestId]
    );

    // 커밋
    await connection.commit();

    res.status(200).json({ message: "Subscription and request created successfully", subscriptionId, requestId });

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();
  } catch (error) {
    // 오류가 발생하면 롤백
    if (dbConnection) {
      await dbConnection.rollback();
    }
    console.error("Error creating subscription and request:", error);
    res.status(500).json({ error: "Failed to create subscription and request" });
  }
});

app.post("/worker/login", async (req, res) => {
  const { AUTH_ID, password } = req.body;
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute(`SELECT AUTH_ID, PW_HASH FROM WORKER_AUTH WHERE AUTH_ID = :AUTH_ID`, [
      AUTH_ID,
    ]);

    if (result.rows.length === 0) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const [userId, hashedPassword] = result.rows[0];
    const isPasswordValid = await bcrypt.compare(password, hashedPassword);

    if (isPasswordValid) {
      res.status(200).json({ message: "Login successful" });
    } else {
      res.status(401).json({ error: "Invalid credentials" });
    }

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();
  } catch (error) {
    console.error("Error logging in:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Login failed" });
  }
});

app.get("/worker/request", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute("SELECT * FROM REQUEST ORDER BY DATE_CREATED DESC");

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "No requests found" });
    }

    const requests = result.rows.map((row) => {
      const request = {
        REQUEST_ID: row[0],
        REQUEST_TYPE: row[1] || "Unknown",
        REQUEST_STATUS: row[2] || "Unknown",
        ADDITIONAL_COMMENT: row[3] || null,
        DATE_CREATED: row[4] ? row[4].toISOString() : new Date().toISOString(),
        DATE_EDITED: row[5] ? row[5].toISOString() : null,
        SUBSCRIPTION_ID: row[6],
      };
      return request;
    });

    res.json(requests);
  } catch (error) {
    console.error("Error fetching requests:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get requests" });
  }
});

app.post("/worker/request/visit", async (req, res) => {
  const { requestId, requestType, problemDetail, solutionDetail } = req.body;
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    await connection.execute("SET TRANSACTION READ WRITE");

    if (requestType == "고장") {
      const visitIdResult = await connection.execute("SELECT VISIT_ID FROM VISIT WHERE REQUEST_ID = :requestId", {
        requestId,
      });

      if (visitIdResult.rows.length === 0) {
        throw new Error("Visit ID not found for the given request ID");
      }

      const visitId = visitIdResult.rows[0][0];

      await connection.execute(
        `INSERT INTO VISIT_REPAIR (VISIT_ID, PROBLEM_DETAIL, SOLUTION_DETAIL)
         VALUES (:visitId, :problemDetail, :solutionDetail)`,
        { visitId, problemDetail, solutionDetail }
      );
    }

    await connection.execute("UPDATE REQUEST SET REQUEST_STATUS = '방문완료' WHERE REQUEST_ID = :requestId", {
      requestId,
    });

    await connection.commit();
    res.status(200).json({ message: "Request accepted successfully" });

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();
  } catch (error) {
    if (dbConnection) {
      await dbConnection.rollback();
      await dbConnection.close();
    }

    if (sshTunnel) {
      sshTunnel.connection.end();
      sshTunnel.localServer.close();
    }

    res.status(500).json({ error: "Failed to accept request", details: error.message });
  }
});

app.post("/worker/request/accept", async (req, res) => {
  const { requestId, workerId, visitDate } = req.body;
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    await connection.execute("SET TRANSACTION READ WRITE");

    if (visitDate) {
      await connection.execute(
        `INSERT INTO VISIT (VISIT_ID, VISIT_DATE, DATE_CREATED, WORKER_ID, REQUEST_ID)
         VALUES (V_SEQ.NEXTVAL, TO_DATE(:visitDate, 'YYYY-MM-DD HH24:MI'), SYSDATE, :workerId, :requestId)`,
        { visitDate, workerId, requestId }
      );
      const result = await connection.execute("SELECT SUBSCRIPTION_ID FROM REQUEST WHERE REQUEST_ID = :requestId", {
        requestId,
      });

      const subscriptionId = result.rows[0][0];

      await connection.execute(
        `UPDATE SUBSCRIPTION SET BEGIN_DATE = TO_DATE(:visitDate, 'YYYY-MM-DD HH24:MI') WHERE SUBSCRIPTION_ID = :subscriptionId`,
        {
          visitDate,
          subscriptionId,
        }
      );
    } else {
      const preferDateResult = await connection.execute(
        `SELECT PREFER_DATE FROM REQUEST_PREFERENCE_DATE WHERE REQUEST_ID = :requestId AND ROWNUM = 1`,
        { requestId }
      );

      const preferDate = preferDateResult.rows[0]?.PREFER_DATE;

      await connection.execute(
        `INSERT INTO VISIT (VISIT_ID, VISIT_DATE, DATE_CREATED, WORKER_ID, REQUEST_ID)
         VALUES (V_SEQ.NEXTVAL, TO_DATE(:preferDate, 'YYYY-MM-DD HH24:MI'), SYSDATE, :workerId, :requestId)`,
        { preferDate, workerId, requestId }
      );

      const result = await connection.execute("SELECT SUBSCRIPTION_ID FROM REQUEST WHERE REQUEST_ID = :requestId", {
        requestId,
      });

      const subscriptionId = result.rows[0].SUBSCRIPTION_ID;

      if (preferDate) {
        await connection.execute(
          `UPDATE SUBSCRIPTION SET BEGIN_DATE = TO_DATE(:preferDate, 'YYYY-MM-DD HH24:MI') WHERE SUBSCRIPTION_ID = :subscriptionId`,
          {
            preferDate,
            subscriptionId,
          }
        );
      }
    }

    await connection.execute(`UPDATE REQUEST SET REQUEST_STATUS = '방문예정' WHERE REQUEST_ID = :requestId`, {
      requestId,
    });

    await connection.commit();
    res.status(200).json({ message: "Request accepted successfully" });

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();
  } catch (error) {
    if (dbConnection) {
      await dbConnection.rollback();
      await dbConnection.close();
    }

    if (sshTunnel) {
      sshTunnel.connection.end();
      sshTunnel.localServer.close();
    }

    res.status(500).json({ error: "Failed to accept request", details: error.message });
  }
});

app.get("/worker/request/:requestId", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const { requestId } = req.params;
    const result = await connection.execute("SELECT * FROM REQUEST WHERE REQUEST_ID = :requestId", [requestId]);

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "No requests found" });
    }

    const requests = result.rows.map((row) => {
      const request = {
        REQUEST_ID: row[0],
        REQUEST_TYPE: row[1] || "Unknown",
        REQUEST_STATUS: row[2] || "Unknown",
        ADDITIONAL_COMMENT: row[3] || null,
        DATE_CREATED: row[4] ? row[4].toISOString() : new Date().toISOString(),
        DATE_EDITED: row[5] ? row[5].toISOString() : null,
        SUBSCRIPTION_ID: row[6],
      };
      return request;
    });

    res.json(requests);
  } catch (error) {
    console.error("Error fetching requests:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get requests" });
  }
});

app.get("/worker/request/:requestId/visit", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const { requestId } = req.params;
    const result = await connection.execute("SELECT * FROM VISIT WHERE REQUEST_ID = :requestId", [requestId]);

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "No visits found" });
    }

    const visits = result.rows.map((row) => {
      const visit = {
        VISIT_ID: row[0],
        VISIT_DATE: row[1] ? row[1].toISOString() : null,
        DATE_CREATED: row[2] ? row[2].toISOString() : new Date().toISOString(),
        WORKER_ID: row[3],
        REQUEST_ID: row[4],
      };
      return visit;
    });

    res.json(visits);
  } catch (error) {
    console.error("Error fetching visits:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get visits" });
  }
});

app.get("/worker/request/:requestId/prefer", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const { requestId } = req.params;
    const result = await connection.execute("SELECT * FROM REQUEST_PREFERENCE_DATE WHERE REQUEST_ID = :requestId", [
      requestId,
    ]);

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "No preferences found" });
    }

    const preferences = result.rows.map((row) => {
      const preference = {
        PREFERENCE_ID: row[0],
        PREFER_DATE: row[1] ? row[1].toISOString() : null,
        REQUEST_ID: row[2],
      };
      return preference;
    });

    res.json(preferences);
  } catch (error) {
    console.error("Error fetching preferences:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get preferences" });
  }
});

app.get("/worker/request/:requestId/specialworker", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const { requestId } = req.params;
    const result = await connection.execute(
      `SELECT
        WORKER_ID, WORKER_NAME, WORKER_SPECIALITY, PHONE_NUMBER
        FROM WORKER
        WHERE WORKER_SPECIALITY =     
        (SELECT MODEL_TYPE
        FROM MODEL
        WHERE MODEL_ID = (SELECT MODEL_ID
        FROM PRODUCT
        WHERE SERIAL_NUMBER=(SELECT SERIAL_NUMBER FROM SUBSCRIPTION
        WHERE SUBSCRIPTION_ID= (SELECT SUBSCRIPTION_ID FROM REQUEST WHERE REQUEST_ID=:requestId))))
        `,
      [requestId]
    );

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "No workers found" });
    }

    const workers = result.rows.map((row) => {
      const worker = {
        WORKER_ID: row[0],
        WORKER_NAME: row[1],
        WORKER_SPECIALTY: row[2],
        PHONE_NUMBER: row[3],
      };
      return worker;
    });

    res.json(workers);
  } catch (error) {
    console.error("Error fetching workers:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get workers" });
  }
});

app.get("/worker/home/stock", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute(
      "SELECT M.MODEL_TYPE, M.MODEL_ID, COALESCE(SUM(CASE WHEN P.PRODUCT_STATUS = '재고' THEN 1 ELSE 0 END), 0) AS STOCK_COUNT, COALESCE(SUM(CASE WHEN P.PRODUCT_STATUS != '재고' THEN 1 ELSE 0 END), 0) AS SUBSCRIPTION_COUNT FROM MODEL M LEFT JOIN PRODUCT P ON M.MODEL_ID = P.MODEL_ID GROUP BY M.MODEL_TYPE, M.MODEL_ID ORDER BY M.MODEL_TYPE"
    );

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "No products found" });
    }

    const products = result.rows.map((row) => {
      const product = {
        MODEL_TYPE: row[0],
        MODEL_ID: row[1],
        STOCK_COUNT: row[2],
        SUBSCRIPTION_COUNT: row[3],
      };
      return product;
    });

    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.json(products);
  } catch (error) {
    console.error("Error fetching products:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get products" });
  }
});

app.get("/worker/home/request", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute(
      "SELECT COALESCE(SUM(CASE WHEN REQUEST_STATUS = '대기중' THEN 1 ELSE 0 END), 0) AS WAITING_COUNT, COALESCE(SUM(CASE WHEN REQUEST_STATUS = '방문예정' THEN 1 ELSE 0 END), 0) AS VISIT_COUNT FROM REQUEST"
    );

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "No requests found" });
    }

    const requests = result.rows.map((row) => {
      const request = {
        WAITING_COUNT: row[0],
        VISIT_COUNT: row[1],
      };
      return request;
    });

    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.json(requests);
  } catch (error) {
    console.error("Error fetching requests:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get requests" });
  }
});

app.get("/worker/product", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute("SELECT P.SERIAL_NUMBER, P.PRODUCT_STATUS, P.MODEL_ID FROM PRODUCT P");

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "No products found" });
    }

    const products = result.rows.map((row) => {
      const product = {
        SERIAL_NUMBER: row[0],
        PRODUCT_STATUS: row[1],
        MODEL_ID: row[2],
      };
      return product;
    });

    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.json(products);
  } catch (error) {
    console.error("Error fetching products:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get products" });
  }
});

app.get("/worker/product/:serialNumber", async (req, res) => {
  let dbConnection = null;
  let sshTunnel = null;

  try {
    const { serialNumber } = req.params;
    const { connection, tunnel } = await connectDatabase();
    dbConnection = connection;
    sshTunnel = tunnel;

    const result = await connection.execute(
      "SELECT P.SERIAL_NUMBER, P.PRODUCT_STATUS, P.MODEL_ID FROM PRODUCT P WHERE P.SERIAL_NUMBER = :serialNumber",
      [serialNumber]
    );

    await connection.close();
    sshTunnel.connection.end();
    sshTunnel.localServer.close();

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "No products found" });
    }

    const products = result.rows.map((row) => {
      const product = {
        SERIAL_NUMBER: row[0],
        PRODUCT_STATUS: row[1],
        MODEL_ID: row[2],
      };
      return product;
    });

    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.json(products);
  } catch (error) {
    console.error("Error fetching products:", error);

    if (dbConnection) {
      try {
        await dbConnection.close();
      } catch (closeError) {
        console.error("Error closing database connection:", closeError);
      }
    }

    if (sshTunnel) {
      try {
        sshTunnel.connection.end();
        sshTunnel.localServer.close();
      } catch (sshCloseError) {
        console.error("Error closing SSH tunnel:", sshCloseError);
      }
    }

    res.status(500).json({ error: "Failed to get products" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
