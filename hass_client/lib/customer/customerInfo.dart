import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../allclass.dart';

Future<List<RequestVisit>> fetchMyRequestData(int customerId) async {
  final response = await http.get(Uri.parse(
      'http://221.163.162.189:53001/customer/info/request/$customerId'));
  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((e) => RequestVisit.fromJson(e)).toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

Future<List<Subscription>> fetchMySubscriptionData(int customerId) async {
  final response = await http.get(Uri.parse(
      'http://221.163.162.189:53001/customer/info/subscription/$customerId'));
  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((e) => Subscription.fromJson(e)).toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

Future<void> cancelRequest(int requestId) async {
  final response = await http.post(
    Uri.parse('http://221.163.162.189:53001/customer/info/request/cancel'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, dynamic>{'requestId': requestId}),
  );
  if (response.statusCode != 200) {
    throw Exception('요청 취소에 실패했습니다.');
  }
}

Future<void> repairRequest(int subscriptionId, String additionalComment,
    String visitDate1, String visitDate2) async {
  final response = await http.post(
    Uri.parse('http://221.163.162.189:53001/customer/info/request/repair'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, dynamic>{
      'subscriptionId': subscriptionId,
      'additionalComment': additionalComment,
      'visitDate1': visitDate1,
      'visitDate2': visitDate2,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('요청 처리에 실패했습니다.');
  }
}

class CustomerInfoPage extends StatefulWidget {
  final int customerId;
  CustomerInfoPage(this.customerId);

  @override
  _CustomerInfoPageState createState() => _CustomerInfoPageState();
}

class _CustomerInfoPageState extends State<CustomerInfoPage> {
  late Future<List<RequestVisit>> futureMyRequestData;
  late Future<List<Subscription>> futureMysubscriptionData;

  @override
  void initState() {
    super.initState();
    futureMyRequestData = fetchMyRequestData(widget.customerId);
    futureMysubscriptionData = fetchMySubscriptionData(widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              flex: 1, // 테이블이 화면의 절반을 차지
              child: FutureBuilder<List<RequestVisit>>(
                future: futureMyRequestData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('에러: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('나의 요청: 요청이 없습니다.'));
                  }

                  final myRequestData = snapshot.data!;
                  return MyRequestTable(myRequestData: myRequestData);
                },
              ),
            ),
            SizedBox(height: 8), // 두 테이블 간 간격
            Expanded(
              flex: 1,
              child: FutureBuilder<List<Subscription>>(
                future: futureMysubscriptionData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('에러: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('나의 구독 현황: 구독중이 아닙니다.'));
                  }

                  final mySubscriptionData = snapshot.data!;
                  return MySubscriptionTable(
                      mySubscriptionData: mySubscriptionData);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyRequestTable extends StatelessWidget {
  final List<RequestVisit> myRequestData;

  MyRequestTable({required this.myRequestData});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '나의 요청',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Table(
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey, width: 0.5),
                ),
                children: [
                  TableRow(
                    children: [
                      tableHeader('구독 ID'),
                      tableHeader('종류'),
                      tableHeader('요청 상태'),
                      tableHeader('방문(선호)일자'),
                      tableHeader(''),
                    ],
                  ),
                  ...myRequestData.map((request) {
                    return TableRow(
                      children: [
                        tableCell(request.subscriptionId.toString()),
                        tableCell(request.requestType),
                        tableCell(request.requestStatus),
                        tableCell(request.visitDateString ?? '없음'),
                        if (request.requestStatus == '대기중')
                          TableCell(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _showCancelDialog(context, request.requestId),
                              child: const Text('취소'),
                            ),
                          )
                        else
                          tableCell(''),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCancelDialog(BuildContext context, int requestId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('요청 취소'),
          content: Text('해당 요청을 취소하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                try {
                  await cancelRequest(requestId);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('요청이 취소되었습니다.')),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('요청 취소에 실패했습니다.')),
                  );
                }
              },
              child: Text('예'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('아니오'),
            ),
          ],
        );
      },
    );
  }

  Widget tableHeader(String text) => TableCell(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            text,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );

  Widget tableCell(String text) => TableCell(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}

class MySubscriptionTable extends StatelessWidget {
  final List<Subscription> mySubscriptionData;

  MySubscriptionTable({required this.mySubscriptionData});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '나의 구독',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Table(
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey, width: 0.5),
                ),
                children: [
                  TableRow(
                    children: [
                      tableHeader('구독 ID'),
                      tableHeader('구독 시작일'),
                      tableHeader('구독 년도'),
                      tableHeader(''),
                    ],
                  ),
                  ...mySubscriptionData.map((subscription) {
                    return TableRow(
                      children: [
                        tableCell(subscription.subscriptionId.toString()),
                        tableCell(subscription.formattedDate(
                            subscription.beginDate ?? DateTime(1970, 1, 1))),
                        tableCell(subscription.subscriptionYear.toString()),
                        TableCell(
                          child: subscription.expiredDate != null &&
                                  subscription.expiredDate!
                                      .isAfter(DateTime.now())
                              ? ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => RepairRequestPage(
                                            subscriptionId:
                                                subscription.subscriptionId),
                                      ),
                                    );
                                  },
                                  child: const Text('수리'),
                                )
                              : const Text(''),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget tableHeader(String text) => TableCell(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            text,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );

  Widget tableCell(String text) => TableCell(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(text),
        ),
      );
}

class RepairRequestPage extends StatefulWidget {
  final int subscriptionId;
  final String additionalComment;
  final String visitDate1;
  final String visitDate2;

  RepairRequestPage({
    required this.subscriptionId,
    this.additionalComment = '',
    this.visitDate1 = '',
    this.visitDate2 = '',
  });

  @override
  _RepairRequestPageState createState() => _RepairRequestPageState();
}

class _RepairRequestPageState extends State<RepairRequestPage> {
  final _additionalCommentController = TextEditingController();

  DateTime? _selectedDate1;
  String? _selectedTime1;
  DateTime? _selectedDate2;
  String? _selectedTime2;

  DateTime currentDateTime = DateTime.now();
  final List<String> _timeIntervals = [
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '12:00',
    '12:30',
    '13:00',
    '13:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
    '17:00',
    '17:30',
    '18:00'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('수리 요청')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildSubscriptionFields(),
                _buildVisitDatePicker(1),
                _buildVisitDatePicker(2),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _handleRepair,
                  child: Text('수리 요청'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionFields() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _additionalCommentController,
            decoration: InputDecoration(
              hintText: '고장 증상',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitDatePicker(int index) {
    DateTime? selectedDate = index == 1 ? _selectedDate1 : _selectedDate2;
    String? selectedTime = index == 1 ? _selectedTime1 : _selectedTime2;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('방문 선호 일자 $index:'),
        SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => _pickDate(index),
          child: Text(selectedDate == null
              ? '일자 선택'
              : '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}'),
        ),
        SizedBox(width: 10),
        DropdownButton<String>(
          value: selectedTime,
          hint: Text('시간 선택'),
          onChanged: (String? newValue) {
            if (newValue != null) {
              _selectTime(index, newValue);
            }
          },
          items: _filteredTimeIntervals(selectedDate).map((time) {
            return DropdownMenuItem<String>(
              value: time,
              child: Text(time),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _pickDate(int index) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDateTime,
      firstDate: currentDateTime,
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        if (index == 1) {
          _selectedDate1 = pickedDate;
          _selectedTime1 = null;
        } else {
          _selectedDate2 = pickedDate;
          _selectedTime2 = null;
        }
      });
    }
  }

  void _selectTime(int index, String time) {
    setState(() {
      if (index == 1) {
        _selectedTime1 = time;
      } else {
        _selectedTime2 = time;
      }
    });
  }

  List<String> _filteredTimeIntervals(DateTime? selectedDate) {
    if (selectedDate == null) return _timeIntervals;

    if (selectedDate.day == currentDateTime.day &&
        selectedDate.month == currentDateTime.month &&
        selectedDate.year == currentDateTime.year) {
      return _timeIntervals.where((time) {
        DateTime intervalTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          int.parse(time.split(':')[0]),
          int.parse(time.split(':')[1]),
        );
        return intervalTime.isAfter(currentDateTime);
      }).toList();
    }
    return _timeIntervals;
  }

  String _formatDateTimeForOracle(DateTime? date, String? time) {
    if (date != null && time != null) {
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $time";
    }
    return "";
  }

  void _handleRepair() {
    final additionalComment = _additionalCommentController.text;

    if (additionalComment.isEmpty ||
        _selectedDate1 == null ||
        _selectedDate2 == null ||
        _selectedTime1 == null ||
        _selectedTime2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('조건을 다시 확인해주세요.')),
      );
      return;
    }

    repairRequest(
            widget.subscriptionId,
            additionalComment,
            _formatDateTimeForOracle(_selectedDate1, _selectedTime1),
            _formatDateTimeForOracle(_selectedDate2, _selectedTime2))
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('요청이 성공적으로 처리되었습니다.')),
      );
      Navigator.pop(context);
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('요청 처리에 실패했습니다.')),
      );
    });
  }
}
