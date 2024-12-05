import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../allclass.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<List<Product>> fetchProductData() async {
  final response =
      await http.get(Uri.parse('http://221.163.162.189:53001/worker/product'));
  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((e) => Product.fromJson(e)).toList();
  } else {
    throw Exception('Failed to load products');
  }
}

Future<List<Product>> fetchProductDataBySerialNumber(
    String serialNumber) async {
  final response = await http.get(
      Uri.parse('http://221.163.162.189:53001/worker/product/${serialNumber}'));
  if (response.statusCode == 200) {
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((e) => Product.fromJson(e)).toList();
  } else {
    throw Exception('Failed to load products');
  }
}

class WorkerProductPage extends StatefulWidget {
  @override
  _WorkerProductPageState createState() => _WorkerProductPageState();
}

class _WorkerProductPageState extends State<WorkerProductPage> {
  late Future<List<Product>> _products;
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  // QR 스캔 관련 변수들
  final TextEditingController _textController = TextEditingController();
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _products = fetchProductData();
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _allProducts
          .where((product) =>
              product.serialNumber.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _toggleCamera() {
    setState(() {
      _isScanning = !_isScanning;
      if (_isScanning) {
        _textController.text = ''; // Clear the text field
        _cameraController.start();
        _showCameraDialog();
      } else {
        _cameraController.stop();
      }
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _textController.text = barcode
              .rawValue!; // Fill the input field with scanned serial number
          _isScanning = false; // Stop scanning
        });
        _cameraController.stop(); // Stop the camera
        Navigator.of(context).pop(); // Close the camera dialog
        _onSearch(); // Automatically trigger the search after scanning
        break;
      }
    }
  }

  // 카메라 화면을 보여주는 다이얼로그
  void _showCameraDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('QR 코드 스캔'),
          content: AspectRatio(
            aspectRatio: 1,
            child: MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isScanning = false;
                });
                _cameraController.stop();
                Navigator.of(context).pop();
              },
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  // Search button press handler
  void _onSearch() async {
    final query = _textController.text;
    if (query.isNotEmpty) {
      try {
        final results = await fetchProductDataBySerialNumber(query);
        setState(() {
          _filteredProducts = results;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('검색 중 오류 발생: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double tableHeight = screenHeight * 0.6;
    return Scaffold(
      body: FutureBuilder<List<Product>>(
          future: _products,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('서버 연결 실패: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('등록된 제품이 없습니다.'));
            } else {
              List<Product> products = snapshot.data!;

              // Initialize the all products list and filtered list
              if (_allProducts.isEmpty) {
                _allProducts = products;
                _filteredProducts =
                    products; // Set filtered products to all products initially
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "제품 관리",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Search input and button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.qr_code_scanner),
                            onPressed: _toggleCamera, // 카메라 버튼 클릭 시
                          ),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              decoration: InputDecoration(
                                labelText: '제품 시리얼번호',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged:
                                  _filterProducts, // Update filter when text changes
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.search),
                            onPressed: _onSearch,
                          ),
                        ],
                      ),
                    ),
                    // Table
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        height: tableHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey, width: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Table(
                            border: TableBorder(
                              horizontalInside:
                                  BorderSide(color: Colors.grey, width: 0.5),
                            ),
                            children: [
                              // Table header
                              TableRow(
                                children: [
                                  TableCell(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text('제품 시리얼번호',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text('모델 ID',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  TableCell(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text('제품상태',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                              // Table rows for filtered products
                              ..._filteredProducts.map((product) {
                                return TableRow(
                                  children: [
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(product.serialNumber),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(product.modelId.toString()),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(product.productStatus),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          }),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _cameraController.dispose();
    super.dispose();
  }
}
