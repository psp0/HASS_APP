import 'package:flutter/material.dart';
import '../allclass.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<List<Subscription>> fetchSubscriptions() async {
  final response = await http
      .get(Uri.parse('http://221.163.162.189:53001/company/subscription'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((e) => Subscription.fromJson(e)).toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

class CompanySubscriptionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double tableHeight = screenHeight * 0.7;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                '구독 관리',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              height: tableHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: FutureBuilder<List<Subscription>>(
                  future: fetchSubscriptions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('No data available.'));
                    } else {
                      List<Subscription> subscriptions = snapshot.data!;

                      return Table(
                        border: TableBorder(
                          horizontalInside:
                              BorderSide(color: Colors.grey, width: 0.5),
                        ),
                        columnWidths: {
                          0: FractionColumnWidth(0.2),
                          1: FractionColumnWidth(0.2),
                          2: FractionColumnWidth(0.4),
                          3: FractionColumnWidth(0.2),
                        },
                        children: [
                          TableRow(
                            children: [
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  child: Text('구독ID',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  child: Text('고객ID',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  child: Text('구독 시작일',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  child: Text('구독년수',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                          ...subscriptions.map((subscription) {
                            return TableRow(
                              children: [
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 4.0),
                                    child: Text(
                                      subscription.subscriptionId.toString(),
                                    ),
                                  ),
                                ),
                                TableCell(
                                    child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  child: Text(
                                    subscription.customerId.toString(),
                                  ),
                                )),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 4.0),
                                    child: Text(subscription.formattedDate(
                                        subscription.beginDate ??
                                            DateTime(1970, 1, 1))),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 4.0),
                                    child: Text(
                                      subscription.subscriptionYear.toString(),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
