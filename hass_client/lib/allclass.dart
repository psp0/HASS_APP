import 'package:intl/intl.dart';

class DateUtils {
  static String formatDate(DateTime date) {
    if (date == DateTime(1970, 1, 1)) {
      return '-'; // Return empty string for Unix epoch
    }
    final DateFormat formatter = DateFormat('yy.MM.dd HH:mm');
    return formatter.format(date);
  }
}

class Customer {
  final int? customerId;
  final String customerName;
  final String mainPhoneNumber;
  final String? subPhoneNumber;
  final String? streetAddress;
  final String? detailedAddress;

  Customer({
    required this.customerId,
    required this.customerName,
    required this.mainPhoneNumber,
    this.subPhoneNumber,
    this.streetAddress,
    this.detailedAddress,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      customerId: json['CUSTOMER_ID'],
      customerName: json['CUSTOMER_NAME'] ?? 'Unknown',
      mainPhoneNumber: json['MAIN_PHONE_NUMBER'] ?? 'Unknown',
      subPhoneNumber: json['SUB_PHONE_NUMBER'],
      streetAddress: json['STREET_ADDRESS'] ?? 'Unknown',
      detailedAddress: json['DETAILED_ADDRESS'] ?? 'Unknown',
    );
  }

  String formattedDate(DateTime date) {
    return DateUtils.formatDate(date);
  }
}

class Request {
  final int requestId;
  final String requestType;
  final String requestStatus;
  final String? additionalComment;
  final DateTime dateCreated;
  final DateTime? dateEdited;
  final int subscriptionId;

  Request({
    required this.requestId,
    required this.requestType,
    required this.requestStatus,
    this.additionalComment,
    required this.dateCreated,
    this.dateEdited,
    required this.subscriptionId,
  });

  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      requestId: json['REQUEST_ID'],
      requestType: json['REQUEST_TYPE'] ?? 'Unknown',
      requestStatus: json['REQUEST_STATUS'] ?? 'Unknown',
      additionalComment: json['ADDITIONAL_COMMENT'],
      dateCreated: json['DATE_CREATED'] != null
          ? DateTime.parse(json['DATE_CREATED'])
          : DateTime.now(),
      dateEdited: json['DATE_EDITED'] != null
          ? DateTime.parse(json['DATE_EDITED'])
          : null,
      subscriptionId: json['SUBSCRIPTION_ID'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'REQUEST_ID': requestId,
      'REQUEST_TYPE': requestType,
      'REQUEST_STATUS': requestStatus,
      'ADDITIONAL_COMMENT': additionalComment,
      'DATE_CREATED': dateCreated.toIso8601String(),
      'DATE_EDITED': dateEdited?.toIso8601String(),
      'SUBSCRIPTION_ID': subscriptionId,
    };
  }

  String formattedDate(DateTime date) {
    return DateUtils.formatDate(date);
  }
}

class RequestVisit extends Request {
  final String? visitDateString;

  RequestVisit({
    required this.visitDateString,
    required int requestId,
    required String requestType,
    required String requestStatus,
    required int subscriptionId,
    required DateTime dateCreated,
  }) : super(
          requestId: requestId,
          requestType: requestType,
          requestStatus: requestStatus,
          subscriptionId: subscriptionId,
          dateCreated: dateCreated,
        );

  factory RequestVisit.fromJson(Map<String, dynamic> json) {
    return RequestVisit(
      visitDateString: json['VISIT_DATE'],
      requestId: json['REQUEST_ID'],
      requestType: json['REQUEST_TYPE'] ?? 'Unknown',
      requestStatus: json['REQUEST_STATUS'] ?? 'Unknown',
      subscriptionId: json['SUBSCRIPTION_ID'],
      dateCreated: json['DATE_CREATED'] != null
          ? DateTime.parse(json['DATE_CREATED'])
          : DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'REQUEST_ID': requestId,
      'REQUEST_TYPE': requestType,
      'REQUEST_STATUS': requestStatus,
      'VISIT_DATE': visitDateString,
      'DATE_CREATED': dateCreated.toIso8601String(),
      'SUBSCRIPTION_ID': subscriptionId,
    };
  }

  @override
  String formattedDate(DateTime date) {
    return DateUtils.formatDate(date);
  }
}

class Product {
  final String serialNumber;
  final String productStatus;
  final int modelId;

  Product({
    required this.serialNumber,
    required this.productStatus,
    required this.modelId,
  });

  // JSON 데이터를 기반으로 객체를 생성하는 팩토리 메서드
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
        serialNumber: json['SERIAL_NUMBER'] ?? 'Unknown',
        productStatus: json['PRODUCT_STATUS'] ?? 'Unknown',
        modelId: json['MODEL_ID'] != null ? json['MODEL_ID'] : 0);
  }

  // 객체를 JSON 형식으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'SERIAL_NUMBER': serialNumber,
      'PRODUCT_STATUS': productStatus,
      'MODEL_ID': modelId,
    };
  }
}

class Worker {
  final int workerId;
  final String workerName;
  final String? workerSpecialty;
  final String phoneNumber;

  Worker({
    required this.workerId,
    required this.workerName,
    this.workerSpecialty,
    required this.phoneNumber,
  });

  // JSON 데이터를 기반으로 객체를 생성하는 팩토리 메서드
  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(
      workerId: json['WORKER_ID'],
      workerName: json['WORKER_NAME'] ?? 'Unknown',
      workerSpecialty: json['WORKER_SPECIALTY'],
      phoneNumber: json['PHONE_NUMBER'] ?? 'Unknown',
    );
  }

  // 객체를 JSON 형식으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'WORKER_ID': workerId,
      'WORKER_NAME': workerName,
      'WORKER_SPECIALTY': workerSpecialty,
      'PHONE_NUMBER': phoneNumber,
    };
  }
}

class Visit {
  final int visitId;
  final String visitType;
  final DateTime? visitDate;
  final DateTime dateCreated;
  final int workerId;
  final int requestId;

  Visit({
    required this.visitId,
    required this.visitType,
    this.visitDate,
    required this.dateCreated,
    required this.workerId,
    required this.requestId,
  });

  // JSON 데이터를 기반으로 객체를 생성하는 팩토리 메서드
  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      visitId: json['VISIT_ID'],
      visitType: json['VISIT_TYPE'] ?? 'Unknown',
      visitDate: json['VISIT_DATE'] != null
          ? DateTime.parse(json['VISIT_DATE'])
          : null,
      dateCreated: json['DATE_CREATED'] != null
          ? DateTime.parse(json['DATE_CREATED'])
          : DateTime.now(),
      workerId: json['WORKER_ID'],
      requestId: json['REQUEST_ID'],
    );
  }

  // 객체를 JSON 형식으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'VISIT_ID': visitId,
      'VISIT_TYPE': visitType,
      'VISIT_DATE': visitDate?.toIso8601String(),
      'DATE_CREATED': dateCreated.toIso8601String(),
      'WORKER_ID': workerId,
      'REQUEST_ID': requestId,
    };
  }

  // 날짜 포매팅 (예시: yyyy-MM-dd HH:mm)
  String formattedDate(DateTime date) {
    return DateUtils.formatDate(date);
  }
}

class Subscription {
  final int subscriptionId;
  final int subscriptionYear;
  final DateTime dateCreated;
  final DateTime? beginDate;
  final DateTime? expiredDate;
  final int customerId;
  final String serialNumber;

  Subscription({
    required this.subscriptionId,
    required this.subscriptionYear,
    required this.dateCreated,
    this.beginDate,
    this.expiredDate,
    required this.customerId,
    required this.serialNumber,
  });

  // JSON 데이터를 기반으로 객체를 생성하는 팩토리 메서드
  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      subscriptionId: json['SUBSCRIPTION_ID'],
      subscriptionYear: json['SUBSCRIPTION_YEAR'],
      dateCreated: json['DATE_CREATED'] != null
          ? DateTime.parse(json['DATE_CREATED'])
          : DateTime.now(),
      beginDate: json['BEGIN_DATE'] != null
          ? DateTime.parse(json['BEGIN_DATE'])
          : null,
      expiredDate: json['EXPIRED_DATE'] != null
          ? DateTime.parse(json['EXPIRED_DATE'])
          : null,
      customerId: json['CUSTOMER_ID'],
      serialNumber: json['SERIAL_NUMBER'] ?? 'Unknown',
    );
  }

  // 객체를 JSON 형식으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'SUBSCRIPTION_ID': subscriptionId,
      'SUBSCRIPTION_YEAR': subscriptionYear,
      'DATE_CREATED': dateCreated.toIso8601String(),
      'BEGIN_DATE': beginDate?.toIso8601String(),
      'EXPIRED_DATE': expiredDate?.toIso8601String(),
      'CUSTOMER_ID': customerId,
      'SERIAL_NUMBER': serialNumber,
    };
  }

  // 날짜 포매팅 (예시: yyyy-MM-dd HH:mm)
  String formattedDate(DateTime date) {
    return DateUtils.formatDate(date);
  }
}

class Model {
  final int modelId;
  final String modelName;
  final String modelType;
  final int yearlyFee;
  final String manufacturer;
  final String color;
  final int energyRating;
  final int releaseYear;

  Model({
    required this.modelId,
    required this.modelName,
    required this.modelType,
    required this.yearlyFee,
    required this.manufacturer,
    required this.color,
    required this.energyRating,
    required this.releaseYear,
  });

  // JSON 데이터를 기반으로 객체를 생성하는 팩토리 메서드
  factory Model.fromJson(Map<String, dynamic> json) {
    return Model(
      modelId: json['MODEL_ID'],
      modelName: json['MODEL_NAME'] ?? 'Unknown',
      modelType: json['MODEL_TYPE'] ?? 'Unknown',
      yearlyFee: json['YEARLY_FEE'] ?? 0,
      manufacturer: json['MANUFACTURER'] ?? 'Unknown',
      color: json['COLOR'] ?? 'Unknown',
      energyRating: json['ENERGY_RATING'] ?? 0,
      releaseYear: json['RELEASE_YEAR'] ?? 0,
    );
  }

  // 객체를 JSON 형식으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'MODEL_ID': modelId,
      'MODEL_NAME': modelName,
      'MODEL_TYPE': modelType,
      'YEARLY_FEE': yearlyFee,
      'MANUFACTURER': manufacturer,
      'COLOR': color,
      'ENERGY_RATING': energyRating,
      'RELEASE_YEAR': releaseYear,
    };
  }
}

class StockSubscription {
  final String modelType;
  final int modelId;
  final int stockCount;
  final int subscriptionCount;

  StockSubscription({
    required this.modelType,
    required this.modelId,
    required this.stockCount,
    required this.subscriptionCount,
  });

  factory StockSubscription.fromJson(Map<String, dynamic> json) {
    return StockSubscription(
      modelType: json['MODEL_TYPE'] ?? '',
      modelId: json['MODEL_ID'] ?? 0,
      stockCount: json['STOCK_COUNT'] ?? 0,
      subscriptionCount: json['SUBSCRIPTION_COUNT'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'MODEL_TYPE': modelType,
      'MODEL_ID': modelId,
      'STOCK_COUNT': stockCount,
      'SUBSCRIPTION_COUNT': subscriptionCount,
    };
  }
}

class RequestCount {
  final int waitingCount;
  final int visitCount;

  RequestCount({required this.waitingCount, required this.visitCount});

  // JSON 데이터를 RequestCount 객체로 변환하는 팩토리 메소드
  factory RequestCount.fromJson(Map<String, dynamic> json) {
    return RequestCount(
      waitingCount:
          int.parse(json['WAITING_COUNT'].toString()), // String일 경우 parse() 사용
      visitCount:
          int.parse(json['VISIT_COUNT'].toString()), // String일 경우 parse() 사용
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'WAITING_COUNT': waitingCount,
      'VISIT_COUNT': visitCount,
    };
  }
}

class RequestPreferenceDate {
  final int preferenceId;
  final DateTime preferDate;
  final int requestId;

  RequestPreferenceDate({
    required this.preferenceId,
    required this.preferDate,
    required this.requestId,
  });

  factory RequestPreferenceDate.fromJson(Map<String, dynamic> json) {
    return RequestPreferenceDate(
      preferenceId: json['PREFERENCE_ID'],
      preferDate: json['PREFER_DATE'] != null
          ? DateTime.parse(json['PREFER_DATE'])
          : DateTime.now(),
      requestId: json['REQUEST_ID'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'PREFERENCE_ID': preferenceId,
      'PREFER_DATE': preferDate.toIso8601String(),
      'REQUEST_ID': requestId,
    };
  }

  String formattedDate(DateTime date) {
    return DateUtils.formatDate(date);
  }
}
