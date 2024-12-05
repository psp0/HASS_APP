//dart코드시작
import 'package:flutter/material.dart';
import '../allclass.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<List<Customer>> fetchCustomersDetail() async {
  final response = await http
      .get(Uri.parse('http://221.163.162.189:53001/company/customers'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((e) => Customer.fromJson(e)).toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

class CompanyCustomerPage extends StatelessWidget {
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
                '고객 관리',
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
                child: FutureBuilder<List<Customer>>(
                  future: fetchCustomersDetail(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('No data available.'));
                    } else {
                      List<Customer> customers = snapshot.data!;

                      return Table(
                        border: TableBorder(
                          horizontalInside:
                              BorderSide(color: Colors.grey, width: 0.5),
                        ),
                        columnWidths: {
                          0: FractionColumnWidth(0.2),
                          1: FractionColumnWidth(0.3),
                          2: FractionColumnWidth(0.3),
                          3: FractionColumnWidth(0.2),
                        },
                        children: [
                          TableRow(
                            children: [
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
                                  child: Text('고객이름',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  child: Text('전화번호',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  child: Text('',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              )
                            ],
                          ),
                          ...customers.map((customer) {
                            return TableRow(
                              children: [
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 4.0),
                                    child: Text(
                                      customer.customerId.toString(),
                                    ),
                                  ),
                                ),
                                TableCell(
                                    child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  child: Text(
                                    customer.customerName.toString(),
                                  ),
                                )),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 4.0),
                                    child: Text(
                                      customer.mainPhoneNumber.toString(),
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _showDetailsDialog(context, customer);
                                      },
                                      child: const Text(
                                        '더보기',
                                        style: TextStyle(fontSize: 12),
                                      ),
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

  void _showDetailsDialog(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("고객 정보"),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("고객 ID: ${customer.customerId}"),
              Text("고객 이름: ${customer.customerName}"),
              Text("전화번호: ${customer.mainPhoneNumber}"),
              Text("보조 전화번호: ${customer.subPhoneNumber ?? 'N/A'}"),
              Text("고객 도로명주소: ${customer.streetAddress ?? 'N/A'}"),
              Text("고객 상세주소: ${customer.detailedAddress ?? 'N/A'}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('닫기'),
            ),
          ],
        );
      },
    );
  }
}
