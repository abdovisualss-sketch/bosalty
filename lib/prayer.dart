import 'dart:math' as math;

/// How the clock of a place works (needed to turn "solar noon" into a clock time).
enum PrayerZone {
  /// Egypt: UTC+2, and UTC+3 from the last Friday of April to the last Thursday of October.
  egypt,

  /// A fixed UTC offset all year (Saudi Arabia, the Gulf, ...).
  fixed,

  /// Use this device's own timezone (for a place the user types by hand).
  device,
}

/// Fajr / Isha angles of a calculation method. Isha can also be "N minutes after Maghrib" (Umm al-Qura).
class PrayerMethod {
  const PrayerMethod(this.fajr, this.isha, [this.ishaAfterMaghribMin = 0]);
  final double fajr, isha;
  final int ishaAfterMaghribMin;
}

const Map<String, PrayerMethod> kPrayerMethods = {
  'egypt': PrayerMethod(19.5, 17.5), // Egyptian General Authority of Survey
  'mwl': PrayerMethod(18, 17), // Muslim World League
  'umm': PrayerMethod(18.5, 0, 90), // Umm al-Qura (Makkah)
};

/// [Arabic, English] names of the methods.
const Map<String, List<String>> kPrayerMethodNames = {
  'egypt': ['الهيئة المصرية للمساحة', 'Egyptian Authority'],
  'mwl': ['رابطة العالم الإسلامي', 'Muslim World League'],
  'umm': ['أم القرى', 'Umm al-Qura'],
};

class PrayerCity {
  const PrayerCity(this.id, this.ar, this.en, this.lat, this.lng, this.zone, this.utc, this.method);
  final String id, ar, en, method;
  final double lat, lng;
  final PrayerZone zone;

  /// Standard UTC offset in hours (used by [PrayerZone.fixed]).
  final double utc;
}

const _eg = PrayerZone.egypt;
const _fx = PrayerZone.fixed;

const List<PrayerCity> kPrayerCities = [
  // ---- Egypt (the first one is the default) ----
  PrayerCity('cairo', 'القاهرة', 'Cairo', 30.0444, 31.2357, _eg, 2, 'egypt'),
  PrayerCity('giza', 'الجيزة', 'Giza', 30.0131, 31.2089, _eg, 2, 'egypt'),
  PrayerCity('alexandria', 'الإسكندرية', 'Alexandria', 31.2001, 29.9187, _eg, 2, 'egypt'),
  PrayerCity('portsaid', 'بورسعيد', 'Port Said', 31.2653, 32.3019, _eg, 2, 'egypt'),
  PrayerCity('suez', 'السويس', 'Suez', 29.9668, 32.5498, _eg, 2, 'egypt'),
  PrayerCity('ismailia', 'الإسماعيلية', 'Ismailia', 30.5965, 32.2715, _eg, 2, 'egypt'),
  PrayerCity('damietta', 'دمياط', 'Damietta', 31.4165, 31.8133, _eg, 2, 'egypt'),
  PrayerCity('mansoura', 'المنصورة', 'Mansoura', 31.0364, 31.3807, _eg, 2, 'egypt'),
  PrayerCity('tanta', 'طنطا', 'Tanta', 30.7865, 31.0004, _eg, 2, 'egypt'),
  PrayerCity('zagazig', 'الزقازيق', 'Zagazig', 30.5877, 31.5019, _eg, 2, 'egypt'),
  PrayerCity('matrouh', 'مرسى مطروح', 'Marsa Matruh', 31.3543, 27.2373, _eg, 2, 'egypt'),
  PrayerCity('fayoum', 'الفيوم', 'Fayoum', 29.3084, 30.8428, _eg, 2, 'egypt'),
  PrayerCity('benisuef', 'بني سويف', 'Beni Suef', 29.0661, 31.0994, _eg, 2, 'egypt'),
  PrayerCity('minya', 'المنيا', 'Minya', 28.1099, 30.7503, _eg, 2, 'egypt'),
  PrayerCity('asyut', 'أسيوط', 'Asyut', 27.1809, 31.1837, _eg, 2, 'egypt'),
  PrayerCity('sohag', 'سوهاج', 'Sohag', 26.5591, 31.6957, _eg, 2, 'egypt'),
  PrayerCity('qena', 'قنا', 'Qena', 26.1551, 32.7160, _eg, 2, 'egypt'),
  PrayerCity('luxor', 'الأقصر', 'Luxor', 25.6872, 32.6396, _eg, 2, 'egypt'),
  PrayerCity('aswan', 'أسوان', 'Aswan', 24.0889, 32.8998, _eg, 2, 'egypt'),
  PrayerCity('hurghada', 'الغردقة', 'Hurghada', 27.2579, 33.8116, _eg, 2, 'egypt'),
  PrayerCity('sharm', 'شرم الشيخ', 'Sharm El-Sheikh', 27.9158, 34.3300, _eg, 2, 'egypt'),
  // ---- Saudi Arabia ----
  PrayerCity('makkah', 'مكة المكرمة', 'Makkah', 21.3891, 39.8579, _fx, 3, 'umm'),
  PrayerCity('madinah', 'المدينة المنورة', 'Madinah', 24.5247, 39.5692, _fx, 3, 'umm'),
  PrayerCity('riyadh', 'الرياض', 'Riyadh', 24.7136, 46.6753, _fx, 3, 'umm'),
  PrayerCity('jeddah', 'جدة', 'Jeddah', 21.4858, 39.1925, _fx, 3, 'umm'),
  PrayerCity('dammam', 'الدمام', 'Dammam', 26.4207, 50.0888, _fx, 3, 'umm'),
  // ---- Gulf, Levant, Iraq ----
  PrayerCity('dubai', 'دبي', 'Dubai', 25.2048, 55.2708, _fx, 4, 'mwl'),
  PrayerCity('abudhabi', 'أبوظبي', 'Abu Dhabi', 24.4539, 54.3773, _fx, 4, 'mwl'),
  PrayerCity('doha', 'الدوحة', 'Doha', 25.2854, 51.5310, _fx, 3, 'umm'),
  PrayerCity('kuwait', 'مدينة الكويت', 'Kuwait City', 29.3759, 47.9774, _fx, 3, 'mwl'),
  PrayerCity('manama', 'المنامة', 'Manama', 26.2285, 50.5860, _fx, 3, 'mwl'),
  PrayerCity('muscat', 'مسقط', 'Muscat', 23.5859, 58.4059, _fx, 4, 'mwl'),
  PrayerCity('amman', 'عمّان', 'Amman', 31.9454, 35.9284, _fx, 3, 'mwl'),
  PrayerCity('baghdad', 'بغداد', 'Baghdad', 33.3152, 44.3661, _fx, 3, 'mwl'),
  // ---- Africa & Turkey (countries with one offset all year) ----
  PrayerCity('khartoum', 'الخرطوم', 'Khartoum', 15.5007, 32.5599, _fx, 2, 'mwl'),
  PrayerCity('tripoli', 'طرابلس (ليبيا)', 'Tripoli (Libya)', 32.8872, 13.1913, _fx, 2, 'mwl'),
  PrayerCity('tunis', 'تونس', 'Tunis', 36.8065, 10.1815, _fx, 1, 'mwl'),
  PrayerCity('algiers', 'الجزائر', 'Algiers', 36.7538, 3.0588, _fx, 1, 'mwl'),
  PrayerCity('istanbul', 'إسطنبول', 'Istanbul', 41.0082, 28.9784, _fx, 3, 'mwl'),
];

DateTime _lastWeekday(int y, int m, int wd /* Mon=0 */) {
  final end = DateTime.utc(y, m + 1, 0); // last day of month m (Dart rolls month 13 over to January)
  return end.subtract(Duration(days: ((end.weekday - 1) - wd) % 7));
}

/// The place the prayer times are worked out for. AppState sets it from the settings, so
/// [prayerTimes] and the helpers below need no extra arguments.
class PrayerConfig {
  PrayerConfig._();

  static const customId = 'custom';
  static PrayerCity city = kPrayerCities.first; // Cairo

  static PrayerCity byId(String? id) {
    for (final c in kPrayerCities) {
      if (c.id == id) return c;
    }
    return kPrayerCities.first;
  }

  /// [id] is a city id or 'custom' (then [lat] / [lng] are used).
  static void apply(String? id, num? lat, num? lng) {
    if (id == customId && lat != null && lng != null) {
      city = PrayerCity(
        customId,
        'موقع مخصّص',
        'Custom location',
        lat.toDouble().clamp(-65.0, 65.0).toDouble(),
        lng.toDouble().clamp(-180.0, 180.0).toDouble(),
        PrayerZone.device,
        0,
        'mwl',
      );
    } else {
      city = byId(id);
    }
  }

  /// Changes whenever the place changes (used to know when to re-schedule notifications).
  static String get sig => '${city.id}:${city.lat}:${city.lng}';

  static String methodLabel(bool rtl) {
    final n = kPrayerMethodNames[city.method] ?? kPrayerMethodNames['mwl']!;
    return rtl ? n[0] : n[1];
  }

  /// UTC offset (hours) of the place on day [d].
  static double offset(DateTime d) {
    switch (city.zone) {
      case PrayerZone.egypt:
        final day = DateTime.utc(d.year, d.month, d.day);
        final summer = !day.isBefore(_lastWeekday(d.year, 4, 4)) && !day.isAfter(_lastWeekday(d.year, 10, 3));
        return summer ? 3.0 : 2.0;
      case PrayerZone.fixed:
        return city.utc;
      case PrayerZone.device:
        return DateTime(d.year, d.month, d.day, 12).timeZoneOffset.inMinutes / 60.0;
    }
  }

  /// "Now" on the wall clock of the place. Only read its year / month / day / hour / minute
  /// (it is flagged UTC, so do not compare it with local DateTimes).
  static DateTime now() {
    final n = DateTime.now();
    return n.toUtc().add(Duration(minutes: (offset(n) * 60).round()));
  }

  /// The real moment (as a local DateTime) when the place's clock shows [hours] on [day].
  static DateTime instant(DateTime day, double hours) {
    final off = (offset(day) * 60).round();
    final mins = (hours * 60).round();
    return DateTime.utc(day.year, day.month, day.day).add(Duration(minutes: mins - off)).toLocal();
  }
}

/// Prayer times in hours (clock of the chosen place) for the day [d].
/// The default place is Cairo with the Egyptian method, exactly as before.
Map<String, double> prayerTimes(DateTime d) {
  final c = PrayerConfig.city;
  final lat = c.lat, lng = c.lng;
  final m = kPrayerMethods[c.method] ?? kPrayerMethods['mwl']!;
  final tz = PrayerConfig.offset(d);
  final epochDays = DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch / 86400000.0;
  final dd = epochDays + 2440587.5 + 0.5 - lng / 360 - 2451545.0;
  double rad(double x) => x * math.pi / 180;
  double deg(double x) => x * 180 / math.pi;
  final g = rad((357.529 + 0.98560028 * dd) % 360);
  final q = (280.459 + 0.98564736 * dd) % 360;
  final L = rad((q + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)) % 360);
  final e = rad(23.439 - 0.00000036 * dd);
  final ra = (deg(math.atan2(math.cos(e) * math.sin(L), math.cos(L))) / 15) % 24;
  final decl = math.asin(math.sin(e) * math.sin(L));
  final eqt = ((q / 15 - ra + 12) % 24) - 12;
  final noon = 12 + tz - lng / 15 - eqt;
  final la = rad(lat);
  double t(double a) {
    final x = (-math.sin(rad(a)) - math.sin(decl) * math.sin(la)) / (math.cos(decl) * math.cos(la));
    return deg(math.acos(x.clamp(-1.0, 1.0))) / 15;
  }

  final asrA = -deg(math.atan(1 / (1 + math.tan((la - decl).abs()))));
  final maghrib = noon + t(0.833);
  return {
    'fajr': noon - t(m.fajr),
    'dhuhr': noon,
    'asr': noon + t(asrA),
    'maghrib': maghrib,
    'isha': m.ishaAfterMaghribMin > 0 ? maghrib + m.ishaAfterMaghribMin / 60 : noon + t(m.isha),
  };
}
