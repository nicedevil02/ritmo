class DailyAct {
  const DailyAct(this.title, {this.note});
  final String title;
  final String? note;
}

/// Mafatih al-Jinan Weekly Acts & Supplications dataset
/// Key: DateTime.weekday (Saturday=6 ... Friday=5)
const Map<int, List<DailyAct>> mafatihWeeklyActs = {
  DateTime.saturday: [
    DailyAct('ذکر «یا رَبَّ الْعالَمِین»', note: '۱۰۰ مرتبه'),
    DailyAct('زیارت پیامبر اکرم (ص) و امیرالمؤمنین (ع)'),
    DailyAct('صدقه دادن، هرچند کم'),
  ],
  DateTime.sunday: [
    DailyAct('ذکر «یا ذَا الْجَلالِ وَ الْإِکْرام»', note: '۱۰۰ مرتبه'),
    DailyAct('زیارت امام حسن (ع) و امام حسین (ع)'),
  ],
  DateTime.monday: [
    DailyAct('ذکر «یا قاضِیَ الْحاجات»', note: '۱۰۰ مرتبه'),
    DailyAct('زیارت امام سجاد، امام باقر و امام صادق (ع)'),
  ],
  DateTime.tuesday: [
    DailyAct('ذکر «یا أَرْحَمَ الرّاحِمین»', note: '۱۰۰ مرتبه'),
    DailyAct('زیارت امام کاظم، امام رضا و امام جواد (ع)'),
    DailyAct('دعای توسل'),
  ],
  DateTime.wednesday: [
    DailyAct('ذکر «یا حَیُّ یا قَیّوم»', note: '۱۰۰ مرتبه'),
    DailyAct('زیارت امام هادی و امام حسن عسکری (ع)'),
  ],
  DateTime.thursday: [
    DailyAct('ذکر «لا إِلهَ إِلَّا اللهُ الْمَلِکُ الْحَقُّ الْمُبین»', note: '۱۰۰ مرتبه'),
    DailyAct('آماده شدن برای شب جمعه: دعای کمیل و زیارت امام حسین (ع)', note: 'امشب'),
  ],
  DateTime.friday: [
    DailyAct('صلوات بر محمد و آل محمد', note: 'دستکم ۱۰۰ مرتبه'),
    DailyAct('غسل جمعه'),
    DailyAct('قرائت سوره کهف'),
    DailyAct('دعای ندبه در صبح جمعه'),
    DailyAct('دعای «اللّهُمَّ کُنْ لِوَلِیِّکَ…» در عصر جمعه'),
    DailyAct('استغفار «أَسْتَغْفِرُ اللهَ رَبّی وَ أَتُوبُ إِلَیْهِ»', note: '۷۰ مرتبه بعد از عصر'),
    DailyAct('زیارت امام زمان (عج) و زیارت اموات'),
  ],
};
