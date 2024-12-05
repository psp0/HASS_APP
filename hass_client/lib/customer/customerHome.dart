import 'package:flutter/material.dart';

class CustomerHomePage extends StatefulWidget {
  @override
  _CustomerHomePageState createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  // 초기 opacity 상태 값
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    // 애니메이션을 시작하여 opacity 값을 변화시키기
    Future.delayed(Duration(seconds: 0), () {
      setState(() {
        _opacity = 1.0; // 애니메이션 시작 후 텍스트의 opacity를 1로 변화
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 배경 이미지
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // 어두운 반투명 레이어 추가 (배경 어두운 색깔)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5), // 어두운 색 반투명 레이어
            ),
          ),

          // 텍스트와 다른 UI 요소들
          Center(
            child: AnimatedOpacity(
              opacity: _opacity, // 애니메이션 적용된 opacity
              duration: Duration(seconds: 2), // 애니메이션 지속 시간
              child: Text(
                '가전제품 구독서비스\nHASS에 오신것을\n환영합니다!',
                style: TextStyle(fontSize: 25, color: Colors.white),
                textAlign: TextAlign.center, // 텍스트 가운데 정렬
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: CustomerHomePage(),
  ));
}
