class Reminder {
  final String id;
  final String title;
  final String description;
  final double amount;
  final DateTime dueDate;
  final ReminderCategory category;
  final String icon;
  final bool isUrgent;
  bool isPaid;

  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.category,
    required this.icon,
    this.isUrgent = false,
    this.isPaid = false,
  });

  bool get isOverdue => DateTime.now().isAfter(dueDate);
  bool get isDueToday => 
    dueDate.year == DateTime.now().year &&
    dueDate.month == DateTime.now().month &&
    dueDate.day == DateTime.now().day;
  bool get isDueTomorrow => 
    dueDate.year == DateTime.now().year &&
    dueDate.month == DateTime.now().month &&
    dueDate.day == DateTime.now().day + 1;

  bool get isUrgentStatus => isUrgent || isDueToday || isDueTomorrow || isOverdue;
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;
}

enum ReminderCategory {
  bill,
  subscription,
  loan,
  split,
}

class RemindersService {
  static List<Reminder> _reminders = [];
  
  static List<Reminder> getMockReminders() {
    if (_reminders.isEmpty) {
      _initializeMockData();
    }
    return _reminders;
  }

  static void _initializeMockData() {
    final now = DateTime.now();
    
    _reminders = [
      Reminder(
        id: '1',
        title: 'Electricity Bill',
        description: 'Monthly electricity bill payment',
        amount: 850.0,
        dueDate: now.add(const Duration(days: 2)),
        category: ReminderCategory.bill,
        icon: '⚡',
        isUrgent: false,
      ),
      Reminder(
        id: '2',
        title: 'Netflix Subscription',
        description: 'Monthly subscription renewal',
        amount: 199.0,
        dueDate: now.add(const Duration(days: 5)),
        category: ReminderCategory.subscription,
        icon: '📺',
        isUrgent: false,
      ),
      Reminder(
        id: '3',
        title: 'Credit Card Payment',
        description: 'Minimum payment due',
        amount: 2500.0,
        dueDate: now.add(const Duration(days: 1)),
        category: ReminderCategory.bill,
        icon: '💳',
        isUrgent: true,
      ),
      Reminder(
        id: '4',
        title: 'Spotify Premium',
        description: 'Music streaming subscription',
        amount: 119.0,
        dueDate: now.add(const Duration(days: 15)),
        category: ReminderCategory.subscription,
        icon: '🎵',
        isUrgent: false,
      ),
      Reminder(
        id: '5',
        title: 'Student Loan EMI',
        description: 'Monthly EMI payment',
        amount: 3200.0,
        dueDate: now.add(const Duration(days: 3)),
        category: ReminderCategory.loan,
        icon: '🎓',
        isUrgent: false,
      ),
      Reminder(
        id: '6',
        title: 'Dinner Split',
        description: 'Split bill with friends',
        amount: 450.0,
        dueDate: now.subtract(const Duration(days: 1)), // Overdue
        category: ReminderCategory.split,
        icon: '🍕',
        isUrgent: false,
      ),
    ];
  }

  static List<Reminder> getUpcomingReminders() {
    final allReminders = getMockReminders();
    final now = DateTime.now();
    
    // Filter unpaid reminders due in next 7 days
    return allReminders
        .where((reminder) => 
          !reminder.isPaid &&
          reminder.dueDate.isAfter(now.subtract(const Duration(days: 1))) && 
          reminder.dueDate.isBefore(now.add(const Duration(days: 7))))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  static List<Reminder> getUrgentReminders() {
    final allReminders = getMockReminders();
    
    // Filter unpaid urgent reminders
    return allReminders
        .where((reminder) => !reminder.isPaid && reminder.isUrgentStatus)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  static List<Reminder> getUnpaidReminders() {
    return getMockReminders().where((r) => !r.isPaid).toList();
  }

  static List<Reminder> getRemindersByCategory(ReminderCategory category) {
    return getMockReminders()
        .where((r) => !r.isPaid && r.category == category)
        .toList();
  }

  static void markAsPaid(String id) {
    final reminder = _reminders.firstWhere((r) => r.id == id);
    reminder.isPaid = true;
  }

  static double getTotalDue() {
    return getUnpaidReminders().fold(0.0, (sum, r) => sum + r.amount);
  }

  static int getThisWeekCount() {
    final now = DateTime.now();
    final weekEnd = now.add(Duration(days: 7 - now.weekday));
    
    return getUnpaidReminders()
        .where((r) => r.dueDate.isBefore(weekEnd) && r.dueDate.isAfter(now))
        .length;
  }
}