//dart코드시작
import 'package:flutter/material.dart';
import '../allclass.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<List<Subscription>> fetchExpiredSubscriptions() async {
  final response = await http
      .get(Uri.parse('http://221.163.162.189:53001/company/expiration'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((e) => Subscription.fromJson(e)).toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

Future<void> subscribeExtend(
  int subscriptionId,
  int addYears,
) async {
  final response = await http.post(
    Uri.parse('http://221.163.162.189:53001/company/expiration/extend'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, dynamic>{
      'subscriptionId': subscriptionId,
      'addYears': addYears,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to subscribe model.');
  }
}

Future<void> subscribeReturn(int subscriptionId, String visitDate) async {
  final response = await http.post(
    Uri.parse('http://221.163.162.189:53001/company/expiration/return'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, dynamic>{
      'subscriptionId': subscriptionId,
      'visitDate': visitDate,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to subscribe model.');
  }
}

class CompanyExpirationPage extends StatelessWidget {
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
                '만료 관리',
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
                  future: fetchExpiredSubscriptions(),
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
                          0: FractionColumnWidth(0.15),
                          1: FractionColumnWidth(0.15),
                          2: FractionColumnWidth(0.3),
                          3: FractionColumnWidth(0.2),
                          4: FractionColumnWidth(0.2),
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
                                  child: Text('구독 만료일',
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
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  child: Text('',
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
                                        subscription.expiredDate ??
                                            DateTime(1970, 1, 1))),
                                  ),
                                ),
                                TableCell(
                                  child: Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        navigateToExtendDetail(
                                          context,
                                          subscription.subscriptionId,
                                        );
                                      },
                                      child: const Text(
                                        '연장',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        navigateToReturnDetail(
                                          context,
                                          subscription.subscriptionId,
                                        );
                                      },
                                      child: const Text(
                                        '회수',
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

  void navigateToExtendDetail(BuildContext context, int subscriptionId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExtendDetailPage(
          subscrtionId: subscriptionId,
        ),
      ),
    );
  }

  void navigateToReturnDetail(BuildContext context, int subscriptionId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReturnDetailPage(
          subscrtionId: subscriptionId,
        ),
      ),
    );
  }
}

class ReturnDetailPage extends StatefulWidget {
  final int subscrtionId;

  ReturnDetailPage({required this.subscrtionId});

  @override
  _ReturnDetailPageState createState() => _ReturnDetailPageState();
}

class _ReturnDetailPageState extends State<ReturnDetailPage> {
  DateTime? _selectedDate;
  String? _selectedTime;

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
      appBar: AppBar(title: Text('회수 요청')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildVisitDatePicker(),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _handleSubscription,
                  child: Text('회수 요청'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisitDatePicker() {
    DateTime? selectedDate = _selectedDate;
    String? selectedTime = _selectedTime;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('방문 일자:'),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => _pickDate(1),
          child: Text(selectedDate == null
              ? '일자 선택'
              : '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}'),
        ),
        const SizedBox(width: 10),
        DropdownButton<String>(
          value: selectedTime,
          hint: const Text('시간 선택'),
          onChanged: (String? newValue) {
            if (newValue != null) {
              _selectTime(1, newValue);
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
          _selectedDate = pickedDate;
          _selectedTime = null;
        }
      });
    }
  }

  void _selectTime(int index, String time) {
    setState(() {
      if (index == 1) {
        _selectedTime = time;
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

  void _handleSubscription() {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('조건을 다시 확인해주세요.')),
      );
      return;
    }

    // 조건이 모두 충족되면 진행
    subscribeReturn(widget.subscrtionId,
            _formatDateTimeForOracle(_selectedDate, _selectedTime))
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회수 요청이 완료되었습니다.')),
      );
      Navigator.pop(context);
    }).catchError((error) {
      // 에러 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회수 요청에 실패했습니다.')),
        );
      }
    });
  }
}

class ExtendDetailPage extends StatefulWidget {
  final int subscrtionId;

  ExtendDetailPage({required this.subscrtionId});

  @override
  _ExtendDetailPageState createState() => _ExtendDetailPageState();
}

class _ExtendDetailPageState extends State<ExtendDetailPage> {
  final _subscriptionYearsController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('구독 연장')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildSubscriptionFields(),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _handleSubscription,
                  child: Text('수정'),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('추가 구독 년수:'),
            SizedBox(width: 10),
            Container(
              width: 50,
              child: TextField(
                controller: _subscriptionYearsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleSubscription() {
    final subscriptionYears =
        int.tryParse(_subscriptionYearsController.text) ?? 0;

    if (subscriptionYears <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('조건을 다시 확인해주세요.')),
      );
      return;
    }

    subscribeExtend(widget.subscrtionId, subscriptionYears).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('연장이 완료되었습니다.')),
      );
      Navigator.pop(context);
    }).catchError((error) {
      // 에러 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구독 연장에 실패했습니다.')),
        );
      }
    });
  }
}
