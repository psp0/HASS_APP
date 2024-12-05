import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../allclass.dart';

Future<List<Request>> fetchRequests() async {
  final response =
      await http.get(Uri.parse('http://221.163.162.189:53001/worker/request'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((request) => Request.fromJson(request)).toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

Future<List<Request>> fetchRequestDetail(requestId) async {
  final response = await http
      .get(Uri.parse('http://221.163.162.189:53001/worker/request/$requestId'));
  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((request) => Request.fromJson(request)).toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

Future<List<Visit>> fetchVisitDetail(requestId) async {
  final response = await http.get(Uri.parse(
      'http://221.163.162.189:53001/worker/request/$requestId/visit'));
  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((visit) => Visit.fromJson(visit)).toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

Future<List<RequestPreferenceDate>> fetchPreferDetail(requestId) async {
  final response = await http.get(Uri.parse(
      'http://221.163.162.189:53001/worker/request/$requestId/prefer'));
  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((e) => RequestPreferenceDate.fromJson(e)).toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

Future<List<Worker>> fetchTargetWorkerDetail(requestId) async {
  final response = await http.get(Uri.parse(
      'http://221.163.162.189:53001/worker/request/$requestId/specialworker'));
  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((e) => Worker.fromJson(e)).toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

Future<void> requestAccept(
    int requestId, int selectedWorkerId, String selectedDate) async {
  final response = await http.post(
    Uri.parse('http://221.163.162.189:53001/worker/request/accept'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, dynamic>{
      'requestId': requestId,
      'workerId': selectedWorkerId,
      'visitDate': selectedDate,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to subscribe model.');
  }
}

Future<void> requestVisit(int requestId, String requestType,
    String problemDetail, String solutionDetail) async {
  final response = await http.post(
    Uri.parse('http://221.163.162.189:53001/worker/request/visit'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, dynamic>{
      'requestId': requestId,
      'requestType': requestType,
      'problemDetail': problemDetail,
      'solutionDetail': solutionDetail,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to subscribe model.');
  }
}

class RequestManagementScreen extends StatefulWidget {
  @override
  _RequestManagementScreenState createState() =>
      _RequestManagementScreenState();
}

class _RequestManagementScreenState extends State<RequestManagementScreen> {
  late Future<List<Request>> _requests;

  @override
  void initState() {
    super.initState();
    _requests = fetchRequests(); // 서버에서 요청 데이터 받아오기
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double tableHeight = screenHeight * 0.7;

    return Scaffold(
      body: FutureBuilder<List<Request>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('서버 연결 실패: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('등록된 요청이 없습니다.'));
          } else {
            List<Request> requests = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '요청 관리',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey, width: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: buildTable(context, requests),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget buildTable(BuildContext context, List<Request> requests) {
    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey, width: 0.5),
      ),
      columnWidths: {
        0: FractionColumnWidth(0.125),
        1: FractionColumnWidth(0.125),
        2: FractionColumnWidth(0.2),
        3: FractionColumnWidth(0.3),
        4: FractionColumnWidth(0.25),
      },
      children: [
        // Header row
        TableRow(
          children: [
            tableHeaderCell('요청 ID'),
            tableHeaderCell('요청 종류'),
            tableHeaderCell('요청 상태'),
            tableHeaderCell('요청 생성일'),
            tableHeaderCell(''),
          ],
        ),
        // Data rows
        ...requests.map((request) {
          return TableRow(
            children: [
              tableDataCell(request.requestId.toString()),
              tableDataCell(request.requestType),
              tableDataCell(request.requestStatus),
              tableDataCell(request.formattedDate(request.dateCreated)),
              TableCell(
                child: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      navigateToRequestDetail(
                        context,
                        request.requestId,
                        request.requestStatus,
                        request.requestType,
                      );
                    },
                    child: const Text(
                      '자세히',
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

  Widget tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget tableDataCell(String text) {
    Color textColor;
    if (text == '대기중') {
      textColor = Colors.orange.shade700;
    } else if (text == '방문완료') {
      textColor = Colors.green;
    } else if (text == '방문예정') {
      textColor = Colors.yellow.shade700;
    } else {
      textColor = Colors.black;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        text,
        style: TextStyle(color: textColor),
      ),
    );
  }

  void navigateToRequestDetail(BuildContext context, int requestId,
      String requestStatus, String requestType) async {
    try {
      var requestDetail = await fetchRequestDetail(requestId);
      Visit? visitDetail;
      List<RequestPreferenceDate> preferDetail = [];

      if (requestStatus == '방문예정' || requestStatus == '방문완료') {
        var visitDetails = await fetchVisitDetail(requestId);
        visitDetail = visitDetails.isNotEmpty ? visitDetails.first : null;
      } else {
        preferDetail = await fetchPreferDetail(requestId);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RequestDetailPage(
            requestId: requestId,
            requestStatus: requestStatus,
            requestDetail: requestDetail.isNotEmpty ? requestDetail[0] : null,
            visitDetail: visitDetail,
            requestType: requestType,
            preferDetail: preferDetail.isNotEmpty ? preferDetail : null,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 로드 오류: $e')),
      );
    }
  }
}

class RequestDetailPage extends StatelessWidget {
  final int requestId;
  final String requestStatus;
  final String requestType;
  final Request? requestDetail; // 요청 상세 정보
  final Visit? visitDetail; // 하나의 방문 정보로 변경
  final List<RequestPreferenceDate>? preferDetail; // 선호 일자 정보 (리스트로 처리)

  RequestDetailPage({
    required this.requestId,
    required this.requestStatus,
    required this.requestType,
    this.requestDetail,
    this.visitDetail,
    this.preferDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('요청 세부사항'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (requestDetail != null) ...[
                  DataTable(
                    columns: [
                      DataColumn(
                          label: Text('항목',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('내용',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: [
                      //볼드체
                      DataRow(cells: [
                        DataCell(Text('요청 ID',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text('${requestDetail?.requestId ?? '없음'}')),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('요청 종류',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text('${requestDetail?.requestType ?? '없음'}')),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('요청 상태',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(
                            Text('${requestDetail?.requestStatus ?? '없음'}')),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('추가 코멘트',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 200),
                            child: Text(
                              '${requestDetail?.additionalComment ?? '없음'}',
                            ),
                          ),
                        ),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('구독 ID',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(
                            Text('${requestDetail?.subscriptionId ?? '없음'}')),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('생성일',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(
                            '${requestDetail?.formattedDate(requestDetail?.dateCreated ?? DateTime(1970, 1, 1)) ?? '없음'}')),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('수정일',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(
                            '${requestDetail?.formattedDate(requestDetail?.dateEdited ?? DateTime(1970, 1, 1)) ?? '없음'}')),
                      ]),
                    ],
                  ),
                ],
                if (preferDetail != null &&
                    preferDetail!.isNotEmpty &&
                    requestStatus == '대기중') ...[
                  DataTable(
                    dataRowHeight: 40,
                    columns: [
                      DataColumn(label: Text('')),
                      DataColumn(label: Text('')),
                    ],
                    rows: preferDetail!.asMap().entries.map((entry) {
                      int index = entry.key;
                      RequestPreferenceDate prefer = entry.value;
                      return DataRow(cells: [
                        DataCell(Text('선호 방문 일자 ${index + 1}',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(
                            '${prefer.formattedDate(prefer.preferDate ?? DateTime(1970, 1, 1))}')),
                      ]);
                    }).toList(),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      navigateToAccept(context, requestId, requestStatus,
                          requestType, preferDetail!);
                    },
                    child: const Text('방문 수락'),
                  ),
                ],
                if (visitDetail != null &&
                    (requestStatus == '방문예정' || requestStatus == "방문완료")) ...[
                  DataTable(
                    dataRowHeight: 40,
                    columns: [
                      DataColumn(label: Text('')),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      DataRow(cells: [
                        DataCell(Text('방문 일자',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(
                            '${visitDetail != null ? visitDetail!.formattedDate(visitDetail!.visitDate ?? DateTime(1970, 1, 1)) : '없음'}')),
                      ]),
                      DataRow(cells: [
                        DataCell(Text(
                          '방문 수락일',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        )),
                        DataCell(Text(
                            '${visitDetail != null ? visitDetail!.formattedDate(visitDetail!.dateCreated ?? DateTime(1970, 1, 1)) : '없음'}')),
                      ]),
                    ],
                  ),
                  if (requestStatus == '방문예정') ...[
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (requestType == '고장') {
                          navigateToVisit(context);
                        } else {
                          requestVisit(requestId, requestType, '', '');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('방문 완료되었습니다.')),
                          );
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('방문 완료'),
                    ),
                  ]
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void navigateToVisit(BuildContext context) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VisitPage(requestId: requestId, requestType: requestType),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 로드 오류: $e')),
      );
    }
  }

  void navigateToAccept(
      BuildContext context,
      int requestId,
      String requestStatus,
      String requestType,
      List<RequestPreferenceDate> preferDetail) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RequestAcceptPage(
            requestId: requestId,
            requestStatus: requestStatus,
            requestType: requestType,
            preferDetail: preferDetail,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 로드 오류: $e')),
      );
    }
  }
}

class VisitPage extends StatelessWidget {
  final int requestId;
  final String requestType;
  final _problemDetailController = TextEditingController();
  final _solutionDetailController = TextEditingController();

  VisitPage({required this.requestId, required this.requestType});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('수리 세부세항'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                TextField(
                  controller: _problemDetailController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '고장 내용',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _solutionDetailController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '수리 내용',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _handleRepair(context),
                  child: const Text('방문 완료'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleRepair(BuildContext context) {
    final problemDetail = _problemDetailController.text;
    final solutionDetail = _solutionDetailController.text;

    if (problemDetail.isEmpty || solutionDetail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('조건을 다시 확인해주세요.')),
      );
      return;
    }

    // 조건이 모두 충족되면 처리
    requestVisit(requestId, requestType, problemDetail, solutionDetail)
      ..then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('방문 완료되었습니다.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('방문 완료에 실패했습니다.')),
        );
      });
  }
}

class RequestAcceptPage extends StatefulWidget {
  final int requestId;
  final String requestStatus;
  final String requestType;
  final List<RequestPreferenceDate> preferDetail;

  const RequestAcceptPage({
    required this.requestId,
    required this.requestStatus,
    required this.requestType,
    required this.preferDetail,
  });

  @override
  RequestAcceptPageState createState() => RequestAcceptPageState();
}

class RequestAcceptPageState extends State<RequestAcceptPage> {
  DateTime? selectedDate;
  int? selectedWorkerId; // null을 허용하여, 초기 값이 없을 경우를 처리
  Future<List<Worker>>? _workers;
  RequestPreferenceDate? selectedPreferenceDate;

  @override
  void initState() {
    super.initState();
    _workers = fetchTargetWorkerDetail(widget.requestId); // 서버에서 요청 데이터 받아오기
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.requestType}요청 세부사항'),
      ),
      body: FutureBuilder<List<Worker>>(
        future: _workers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('서버 연결 실패: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('등록된 요청이 없습니다.'));
          } else {
            List<Worker> workers = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      if (widget.preferDetail.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('방문 일자:'),
                            const SizedBox(width: 10),
                            DropdownButton<RequestPreferenceDate>(
                              value: selectedPreferenceDate,
                              onChanged: (RequestPreferenceDate? newValue) {
                                setState(() {
                                  selectedPreferenceDate = newValue;
                                });
                              },
                              items: [
                                const DropdownMenuItem<RequestPreferenceDate>(
                                  value: null,
                                  child: Text('일자 선택'),
                                ),
                                ...widget.preferDetail.map<
                                    DropdownMenuItem<RequestPreferenceDate>>(
                                  (RequestPreferenceDate value) {
                                    return DropdownMenuItem<
                                        RequestPreferenceDate>(
                                      value: value,
                                      child: Text(value
                                          .formattedDate(value.preferDate)),
                                    );
                                  },
                                ),
                              ],
                              dropdownColor: Theme.of(context).canvasColor,
                            ),
                          ],
                        ),
                      ],
                      if (workers.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('담당 기사 이름:'),
                            const SizedBox(width: 10),
                            DropdownButton<int>(
                              value: selectedWorkerId,
                              onChanged: (int? newIndex) {
                                setState(() {
                                  selectedWorkerId = newIndex;
                                });
                              },
                              items: [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('선택'),
                                ),
                                ...workers
                                    .map<DropdownMenuItem<int>>((Worker value) {
                                  return DropdownMenuItem<int>(
                                    value: value.workerId,
                                    child: Text(value.workerName),
                                  );
                                }).toList(),
                              ],
                            ),
                          ],
                        )
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          _handleAccept();
                        },
                        child: const Text('방문 수락'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  String _formatDateTimeForOracle(DateTime? date) {
    if (date != null) {
      // YYYY-MM-DD HH24:MI
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }
    return "";
  }

  void _handleAccept() {
    final selectedDate = selectedPreferenceDate?.preferDate;
    final workerId = selectedWorkerId;

    if (selectedDate == null || workerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('조건을 다시 확인해주세요.')),
      );
      return;
    }

    requestAccept(
        widget.requestId, workerId, _formatDateTimeForOracle(selectedDate))
      ..then((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('방문 수락이 완료되었습니다.')),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
          //isFirst로 나가면서 true도 같이 반환하는법
        }
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('방문 수락에 실패했습니다.')),
        );
      });
  }
}
