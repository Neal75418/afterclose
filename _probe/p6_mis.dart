// TEMP PROBE — delete after verification run.
import 'package:daredevil/data/remote/intraday_quote_client.dart';

Future<void> main() async {
  final c = IntradayQuoteClient();
  final sw = Stopwatch()..start();
  try {
    final q = await c.fetchQuotes({'2330': 'TWSE', '6538': 'TPEx'});
    print('MIS elapsed=${sw.elapsedMilliseconds}ms parsed=${q.length}/2');
    for (final k in ['2330', '6538']) {
      final v = q[k];
      if (v == null) {
        print('$k => MISSING');
        continue;
      }
      print(
        '$k name=${v.name} price=${v.price} prevClose=${v.previousClose} '
        'open=${v.open} high=${v.high} low=${v.low} vol=${v.volume} '
        't=${v.time} chg=${v.changePercent.toStringAsFixed(2)}%',
      );
    }
  } catch (e, s) {
    print('MIS FAILED: $e');
    print(s);
  } finally {
    c.close();
  }
}
