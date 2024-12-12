import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'worker/workerRequest.dart';
import 'worker/workerHome.dart';
import 'worker/workerProduct.dart';
import 'customer/customerInfo.dart';
import 'customer/customerModel.dart';
import 'customer/customerHome.dart';
import 'company/companyExpiration.dart';
import 'company/companySubscription.dart';
import 'company/companyCustomer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HASS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.blue.shade50,
        dialogBackgroundColor: Colors.blue.shade100,
        dropdownMenuTheme: const DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: MaterialStatePropertyAll(Colors.blue),
          ),
        ),
        datePickerTheme: const DatePickerThemeData(
          backgroundColor:
              Color(0xFFBBDEFB), // Equivalent to Colors.blue.shade100
          headerBackgroundColor: Colors.white,
          headerHeadlineStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
            labelStyle: TextStyle(color: Colors.white),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade200,
          //텍스트 컬러 화이트 &한글폰트
          titleTextStyle: GoogleFonts.nanumGothic(
            color: Colors.white,
            fontSize: 20,
            //볼드
            fontWeight: FontWeight.bold,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.blue.shade100,
          selectedItemColor: Colors.blue.shade800,
          unselectedItemColor: Colors.blue.shade400,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade300,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const AppPage(),
    );
  }
}

class LoginStatus {
  static bool isCustomerLoggedIn = false;
  static bool isCompanyLoggedIn = false;
  static bool isWorkerLoggedIn = false;
  static int? customerId = 0;
}

class AppPage extends StatefulWidget {
  const AppPage({super.key});
  @override
  _AppPageState createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  int _selectedIndex = 0;

  List<Widget> _pages = [CustomerHomePage()];

  List<BottomNavigationBarItem> _bottomNavItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: '메인',
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logout() {
    setState(() {
      LoginStatus.isCustomerLoggedIn = false;
      LoginStatus.isCompanyLoggedIn = false;
      LoginStatus.isWorkerLoggedIn = false;
      LoginStatus.customerId = 0;
      _selectedIndex = 0;
      _updatePageContent();
    });
  }

  void _updatePageContent() {
    setState(() {
      _pages = [];
      _bottomNavItems = [];
      if (LoginStatus.isCustomerLoggedIn) {
        _pages.add(CustomerHomePage());
        _bottomNavItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '메인',
          ),
        );
        _pages.add(CustomerModelPage(LoginStatus.customerId ?? 0));
        _bottomNavItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.tv),
            label: '모델 구독',
          ),
        );
        _pages.add(CustomerInfoPage(LoginStatus.customerId ?? 0));
        _bottomNavItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '나의 정보',
          ),
        );
      } else if (LoginStatus.isCompanyLoggedIn) {
        _pages.add(CompanyExpirationPage());
        _bottomNavItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.date_range),
            label: '만료관리',
          ),
        );
        _pages.add(CompanySubscriptionPage());
        _bottomNavItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.real_estate_agent),
            label: '구독관리',
          ),
        );
        _pages.add(CompanyCustomerPage());
        _bottomNavItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: '고객관리',
          ),
        );
      } else if (LoginStatus.isWorkerLoggedIn) {
        _pages.add(WorkerHomePage());
        _bottomNavItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '현황판',
          ),
        );
        _pages.add(RequestManagementScreen());
        _bottomNavItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.send),
            label: '요청관리',
          ),
        );
        _pages.add(WorkerProductPage());
        _bottomNavItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.tv),
            label: '제품관리',
          ),
        );
      } else {
        _pages.add(CustomerHomePage());
        _bottomNavItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '메인',
          ),
        );
        _pages.add(const LoginScreen());
        _bottomNavItems.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.login),
            label: '로그인',
          ),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePageContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HASS'),
        titleTextStyle: GoogleFonts.leckerliOne(
          color: Colors.white,
          fontSize: 35, // 메인화면 AppBar 글자 크기 수정
        ),
        actions: [
          if (LoginStatus.isCustomerLoggedIn ||
              LoginStatus.isCompanyLoggedIn ||
              LoginStatus.isWorkerLoggedIn)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _logout,
            ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: _bottomNavItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class DriverInfoPage extends StatelessWidget {
  const DriverInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기사 정보'),
      ),
      body: const Center(
        child: Text(
          '기사 정보 페이지 내용',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!LoginStatus.isCompanyLoggedIn &&
                !LoginStatus.isWorkerLoggedIn) ...[
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CustomerLoginPage()),
                ),
                child: const Text('고객 로그인'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CompanyLoginPage()),
                ),
                child: const Text('회사 로그인'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => WorkerLoginPage()),
                ),
                child: const Text('기사 로그인'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class CustomerSignupPage extends StatefulWidget {
  @override
  _CustomerSignupPageState createState() => _CustomerSignupPageState();
}

class _CustomerSignupPageState extends State<CustomerSignupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _authIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mainPhoneController = TextEditingController();
  final TextEditingController _subPhoneController = TextEditingController();
  final TextEditingController _streetAddressController =
      TextEditingController();
  final TextEditingController _detailedAddressController =
      TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();

  bool isAuthIdAvailable = false;

  // 비밀번호 조건 확인 함수
  bool _isPasswordValid(String password) {
    final passwordRegex =
        r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$';
    return RegExp(passwordRegex).hasMatch(password);
  }

  Future<void> _signup(BuildContext context) async {
    if (!isAuthIdAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디 중복 확인이 필요합니다.')),
      );
      return;
    }

    final password = _passwordController.text;

    if (!_isPasswordValid(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호는 8자 이상, 영문자, 숫자, 특수문자를 포함해야 합니다.')),
      );
      return;
    }

    final customerName = _nameController.text;
    final authId = _authIdController.text;
    final mainPhoneNumber = _mainPhoneController.text;
    final subPhoneNumber = _subPhoneController.text;
    final streetAddress = _streetAddressController.text;
    final detailedAddress = _detailedAddressController.text;
    final postalCode = _postalCodeController.text;

    try {
      final response = await http.post(
        Uri.parse("http://221.163.162.189:53001/customer/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "customerName": customerName,
          "authId": authId,
          "pw": password,
          "mainPhoneNumber": mainPhoneNumber,
          "subPhoneNumber": subPhoneNumber,
          "streetAddress": streetAddress,
          "detailedAddress": detailedAddress,
          "postalCode": postalCode,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 성공!')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 실패, 다시 시도해주세요')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 실패, 다시 시도해주세요')),
      );
    }
  }

  Future<void> _checkAuthId(BuildContext context) async {
    final authId = _authIdController.text;

    try {
      final response = await http.post(
        Uri.parse("http://221.163.162.189:53001/customer/signup/check"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "AUTH_ID": authId,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          isAuthIdAvailable = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용 가능한 아이디입니다.')),
        );
      } else {
        setState(() {
          isAuthIdAvailable = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 사용 중인 아이디입니다.')),
        );
      }
    } catch (e) {
      setState(() {
        isAuthIdAvailable = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디 중복 확인 실패, 다시 시도해주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            TextField(
              controller: _authIdController,
              decoration: const InputDecoration(labelText: '아이디'),
            ),
            ElevatedButton(
              onPressed: () => _checkAuthId(context),
              child: const Text('중복확인'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: '비밀번호'),
              obscureText: true,
            ),
            const Text(
              "8자 이상, 영문자, 숫자, 특수문자를 반드시 포함",
              style: TextStyle(color: Colors.red),
            ),
            TextField(
              controller: _mainPhoneController,
              decoration: const InputDecoration(labelText: '핸드폰 번호'),
            ),
            const Text(
              "형식: 010-1234-5678",
              style: TextStyle(color: Colors.red),
            ),
            TextField(
              controller: _subPhoneController,
              decoration: const InputDecoration(labelText: '보조 핸드폰 번호 (선택)'),
            ),
            TextField(
              controller: _streetAddressController,
              decoration: const InputDecoration(labelText: '주소 (도로명)'),
            ),
            TextField(
              controller: _detailedAddressController,
              decoration: const InputDecoration(labelText: '상세 주소'),
            ),
            TextField(
              controller: _postalCodeController,
              decoration: const InputDecoration(labelText: '우편번호'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty &&
                    _authIdController.text.isNotEmpty &&
                    _passwordController.text.isNotEmpty &&
                    _mainPhoneController.text.isNotEmpty &&
                    _streetAddressController.text.isNotEmpty &&
                    _detailedAddressController.text.isNotEmpty &&
                    _postalCodeController.text.isNotEmpty) {
                  _signup(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('조건을 다시 확인해주세요')),
                  );
                }
              },
              child: const Text('회원가입'),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerLoginPage extends StatelessWidget {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  CustomerLoginPage({super.key});

  Future<void> _login(BuildContext context) async {
    final customerAuthId = _idController.text;
    final password = _pwController.text;

    try {
      final response = await http.post(
        Uri.parse("http://221.163.162.189:53001/customer/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "AUTH_ID": customerAuthId,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        LoginStatus.isCustomerLoggedIn = true;
        LoginStatus.customerId = responseBody['customerId'];

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AppPage()),
          (Route<dynamic> route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('다시 확인해주세요')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인에 실패하였습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('고객 로그인')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: 'ID'),
            ),
            TextField(
              controller: _pwController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _login(context),
                  child: const Text('로그인'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CustomerSignupPage()),
                    );
                  },
                  child: const Text('회원가입'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class WorkerLoginPage extends StatelessWidget {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  WorkerLoginPage({super.key});

  Future<void> _login(BuildContext context) async {
    final authId = _idController.text;
    final password = _pwController.text;

    try {
      final response = await http.post(
        Uri.parse("http://221.163.162.189:53001/worker/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "AUTH_ID": authId,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        jsonDecode(response.body);

        LoginStatus.isWorkerLoggedIn = true;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AppPage()),
          (Route<dynamic> route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('다시 확인해주세요')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed, please try again')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기사 로그인')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: 'ID'),
            ),
            TextField(
              controller: _pwController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _login(context),
              child: const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}

class CompanyLoginPage extends StatelessWidget {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  CompanyLoginPage({super.key});

  Future<void> _login(BuildContext context) async {
    final companyId = _idController.text;
    final password = _pwController.text;

    try {
      final response = await http.post(
        Uri.parse("http://221.163.162.189:53001/company/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "AUTH_ID": companyId,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        LoginStatus.isCompanyLoggedIn = true;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AppPage()),
          (Route<dynamic> route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('다시 확인해주세요')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed, please try again')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회사 로그인')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: 'ID'),
            ),
            TextField(
              controller: _pwController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _login(context),
              child: const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}
