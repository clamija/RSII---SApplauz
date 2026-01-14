class SalesReport {
  final DateTime startDate;
  final DateTime endDate;
  final double totalRevenue;
  final int totalOrders;
  final int totalTicketsSold;
  final List<SalesByInstitution> salesByInstitution;
  final List<SalesByShow> salesByShow;
  final List<DailySales> dailySales;

  SalesReport({
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.totalOrders,
    required this.totalTicketsSold,
    required this.salesByInstitution,
    required this.salesByShow,
    required this.dailySales,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    return SalesReport(
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      totalOrders: json['totalOrders'] as int,
      totalTicketsSold: json['totalTicketsSold'] as int,
      salesByInstitution: (json['salesByInstitution'] as List<dynamic>?)
          ?.map((i) => SalesByInstitution.fromJson(i as Map<String, dynamic>))
          .toList() ?? [],
      salesByShow: (json['salesByShow'] as List<dynamic>?)
          ?.map((s) => SalesByShow.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      dailySales: (json['dailySales'] as List<dynamic>?)
          ?.map((d) => DailySales.fromJson(d as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

class SalesByInstitution {
  final int institutionId;
  final String institutionName;
  final double revenue;
  final int ordersCount;
  final int ticketsSold;

  SalesByInstitution({
    required this.institutionId,
    required this.institutionName,
    required this.revenue,
    required this.ordersCount,
    required this.ticketsSold,
  });

  factory SalesByInstitution.fromJson(Map<String, dynamic> json) {
    return SalesByInstitution(
      institutionId: json['institutionId'] as int,
      institutionName: json['institutionName'] as String,
      revenue: (json['revenue'] as num).toDouble(),
      ordersCount: json['ordersCount'] as int,
      ticketsSold: json['ticketsSold'] as int,
    );
  }
}

class SalesByShow {
  final int showId;
  final String showTitle;
  final double revenue;
  final int ordersCount;
  final int ticketsSold;

  SalesByShow({
    required this.showId,
    required this.showTitle,
    required this.revenue,
    required this.ordersCount,
    required this.ticketsSold,
  });

  factory SalesByShow.fromJson(Map<String, dynamic> json) {
    return SalesByShow(
      showId: json['showId'] as int,
      showTitle: json['showTitle'] as String,
      revenue: (json['revenue'] as num).toDouble(),
      ordersCount: json['ordersCount'] as int,
      ticketsSold: json['ticketsSold'] as int,
    );
  }
}

class DailySales {
  final DateTime date;
  final double revenue;
  final int ordersCount;
  final int ticketsSold;

  DailySales({
    required this.date,
    required this.revenue,
    required this.ordersCount,
    required this.ticketsSold,
  });

  factory DailySales.fromJson(Map<String, dynamic> json) {
    return DailySales(
      date: DateTime.parse(json['date'] as String),
      revenue: (json['revenue'] as num).toDouble(),
      ordersCount: json['ordersCount'] as int,
      ticketsSold: json['ticketsSold'] as int,
    );
  }
}
