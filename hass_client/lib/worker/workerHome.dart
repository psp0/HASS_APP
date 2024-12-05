import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../allclass.dart';

Future<List<StockSubscription>> fetchStockData() async {
  final response = await http
      .get(Uri.parse('http://221.163.162.189:53001/worker/home/stock'));
  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse
        .map((stock) => StockSubscription.fromJson(stock))
        .toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

Future<List<RequestCount>> fetchRequestData() async {
  final response = await http
      .get(Uri.parse('http://221.163.162.189:53001/worker/home/request'));
  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((stock) => RequestCount.fromJson(stock)).toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

class WorkerHomePage extends StatefulWidget {
  @override
  _WorkerHomePageState createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage> {
  late Future<List<RequestCount>> futureRequestDetail;
  late Future<List<StockSubscription>> futureStockSubscriptionData;

  @override
  void initState() {
    super.initState();
    // 각 API를 따로 호출
    futureRequestDetail = fetchRequestData();
    futureStockSubscriptionData = fetchStockData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Request 관련 FutureBuilder
            FutureBuilder<List<RequestCount>>(
              future: futureRequestDetail,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('에러: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('데이터가 없습니다.'));
                }

                final requestData = snapshot.data!;

                return RequestInfoWidget(requestData: requestData);
              },
            ),
            SizedBox(height: 20),

            Text(
              '모델별 재고 현황',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            // Stock 관련 FutureBuilder
            FutureBuilder<List<StockSubscription>>(
              future: futureStockSubscriptionData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('에러: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('데이터가 없습니다.'));
                }

                final stockData = snapshot.data!;

                return StockInfoWidget(stockData: stockData);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Request 관련 정보를 표시하는 위젯
class RequestInfoWidget extends StatelessWidget {
  final List<RequestCount> requestData;

  RequestInfoWidget({required this.requestData});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text("요청 대기중:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Text(requestData[0].waitingCount.toString(),
            style: TextStyle(fontSize: 20)),
        SizedBox(width: 15),
        Text("자택 방문예정:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Text(requestData[0].visitCount.toString(),
            style: TextStyle(fontSize: 20)),
      ],
    );
  }
}

class StockInfoWidget extends StatelessWidget {
  final List<StockSubscription> stockData;

  StockInfoWidget({required this.stockData});

  @override
  Widget build(BuildContext context) {
    Map<String, List<StockSubscription>> groupedData = {};

    // stockData를 모델 타입별로 그룹화
    for (var item in stockData) {
      if (!groupedData.containsKey(item.modelType)) {
        groupedData[item.modelType] = [];
      }
      groupedData[item.modelType]!.add(item);
    }

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 0.5), // 외부 테두리
          borderRadius: BorderRadius.circular(10), // 라운드 처리
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical, // 세로 방향으로 스크롤
                child: Table(
                  border: TableBorder(
                    verticalInside:
                        BorderSide(color: Colors.grey, width: 0.5), // 세로줄만 그리기
                    horizontalInside:
                        BorderSide(color: Colors.grey, width: 0.5), // 가로줄만 그리기
                  ),
                  children: [
                    TableRow(
                      children: [
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('제품 종류',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('모델 ID',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('재고수량',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('구독(대기)중',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    // 각 그룹별로 묶어서 표시
                    for (var modelType in groupedData.keys)
                      ...groupedData[modelType]!.map((item) {
                        return TableRow(
                          children: [
                            TableCell(
                              child: item == groupedData[modelType]!.first
                                  ? Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(item.modelType),
                                    )
                                  : Container(),
                            ),
                            TableCell(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(item.modelId.toString()),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(item.stockCount.toString()),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(item.subscriptionCount.toString()),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
