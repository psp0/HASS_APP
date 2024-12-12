import 'package:flutter/material.dart';
import '../allclass.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';

Future<List<Model>> fetchRequests() async {
  final response =
      await http.get(Uri.parse('http://221.163.162.189:53001/customer/model'));

  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((e) => Model.fromJson(e)).toList();
  } else {
    throw Exception('요청을 서버에서 불러오는 데 실패했습니다.');
  }
}

// 구독신청 api
Future<void> subscribeModel(int customerId, int modelId, int subscriptionYears,
    String comment, String visitDate1, String visitDate2) async {
  final response = await http.post(
    Uri.parse('http://221.163.162.189:53001/customer/model/subscribe'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, dynamic>{
      'customerId': customerId,
      'modelId': modelId,
      'subscriptionYears': subscriptionYears,
      'comment': comment,
      'visitDate1': visitDate1,
      'visitDate2': visitDate2,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to subscribe model.');
  }
}

class CustomerModelPage extends StatelessWidget {
  final int customerId;
  CustomerModelPage(this.customerId);

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
                '모델 구독',
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
                child: FutureBuilder<List<Model>>(
                  future: fetchRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('No data available.'));
                    } else {
                      List<Model> models = snapshot.data!;

                      return Table(
                        border: TableBorder(
                          horizontalInside:
                              BorderSide(color: Colors.grey, width: 0.5),
                        ),
                        columnWidths: {
                          0: FractionColumnWidth(0.1),
                          1: FractionColumnWidth(0.25),
                          2: FractionColumnWidth(0.4),
                          3: FractionColumnWidth(0.25),
                        },
                        children: [
                          TableRow(
                            children: [
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  child: Text('종류',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  child: Text('모델 사진',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 4.0),
                                  child: Text('모델 이름',
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
                          ...models.map((model) {
                            String imagePath =
                                'assets/model${model.modelId}.jpg';
                            return TableRow(
                              children: [
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 4.0),
                                    child: Text(model.modelType,
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 4.0),
                                    child: Image.asset(imagePath,
                                        width: 50, height: 50),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 4.0),
                                    child: Text(model.modelName),
                                  ),
                                ),
                                TableCell(
                                  child: Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        navigateToModelDetail(
                                            context,
                                            model.modelId,
                                            model.modelName,
                                            model.modelType,
                                            model.yearlyFee,
                                            model.manufacturer,
                                            model.color,
                                            model.energyRating,
                                            model.releaseYear,
                                            customerId);
                                      },
                                      child: const Text(
                                        '더보기',
                                        style: TextStyle(fontSize: 12),
                                        softWrap: false,
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

  void navigateToModelDetail(
      BuildContext context,
      int modelId,
      String modelName,
      String modelType,
      int yearlyFee,
      String manufacturer,
      String color,
      int energyRating,
      int releaseYear,
      int customerId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModelDetailPage(
          modelId: modelId,
          modelName: modelName,
          modelType: modelType,
          yearlyFee: yearlyFee,
          manufacturer: manufacturer,
          color: color,
          energyRating: energyRating,
          releaseYear: releaseYear,
          customerId: customerId,
        ),
      ),
    );
  }
}

class ModelDetailPage extends StatefulWidget {
  final int modelId;
  final String modelName;
  final String modelType;
  final int yearlyFee;
  final String manufacturer;
  final String color;
  final int energyRating;
  final int releaseYear;
  final int customerId;

  ModelDetailPage({
    required this.modelId,
    required this.modelName,
    required this.modelType,
    required this.yearlyFee,
    required this.manufacturer,
    required this.color,
    required this.energyRating,
    required this.releaseYear,
    required this.customerId,
  });

  @override
  _ModelDetailPageState createState() => _ModelDetailPageState();
}

class _ModelDetailPageState extends State<ModelDetailPage> {
  final _subscriptionYearsController = TextEditingController();
  final _commentController = TextEditingController();

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
      appBar: AppBar(title: Text('모델 상세 정보')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildModelInfoTable(),
                _buildSubscriptionFields(),
                _buildVisitDatePicker(1),
                _buildVisitDatePicker(2),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _handleSubscription,
                  child: Text('구독'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelInfoTable() {
    return DataTable(
      dataRowHeight: 30,
      columns: [
        DataColumn(
            label: Text('항목', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('내용', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: [
        DataRow(cells: [
          DataCell(
              Text('모델 이름', style: TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text('${widget.modelName}')),
        ]),
        DataRow(cells: [
          DataCell(
              Text('출시 연도', style: TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text('${widget.releaseYear}')),
        ]),
        DataRow(cells: [
          DataCell(Text('제조사', style: TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text('${widget.manufacturer}')),
        ]),
        DataRow(cells: [
          DataCell(Text('색상', style: TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text('${widget.color}')),
        ]),
        DataRow(cells: [
          DataCell(
              Text('에너지 등급', style: TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text('${widget.energyRating}')),
        ]),
        DataRow(cells: [
          DataCell(
              Text('연 구독료', style: TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text('${widget.yearlyFee}')),
        ]),
      ],
    );
  }

  Widget _buildSubscriptionFields() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('구독 년수:'),
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
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: '기타 코멘트',
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

  void _handleSubscription() {
    final subscriptionYears =
        int.tryParse(_subscriptionYearsController.text) ?? 0;
    final comment = _commentController.text;

    if (subscriptionYears <= 0 ||
        _selectedDate1 == null ||
        _selectedDate2 == null ||
        _selectedTime1 == null ||
        _selectedTime2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('조건을 다시 확인해주세요.')),
      );
      return;
    }

    // 조건이 모두 충족되면 구독 처리
    subscribeModel(
      widget.customerId,
      widget.modelId,
      subscriptionYears,
      comment,
      _formatDateTimeForOracle(_selectedDate1, _selectedTime1),
      _formatDateTimeForOracle(_selectedDate2, _selectedTime2),
    ).then((_) {
      // 구독 신청 성공하면 완료되었다고 snackbar띄우고 나가기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구독 신청이 완료되었습니다.')),
      );
      Navigator.pop(context);
    }).catchError((error) {
      // 에러 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('재고 부족으로 구독 신청에 실패했습니다.')),
        );
      }
    });
  }
}
