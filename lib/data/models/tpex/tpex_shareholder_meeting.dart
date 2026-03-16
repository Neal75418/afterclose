import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/tw_parse_utils.dart';

/// TPEX 股東會資料（來源：櫃買中心 ap41_O API）
///
/// 包含上櫃公司的股東常會/臨時會日期、地點、是否改選董監及電子投票等資訊。
class TpexShareholderMeeting {
  const TpexShareholderMeeting({
    required this.symbol,
    required this.companyName,
    required this.meetingType,
    required this.meetingDate,
    this.location,
    required this.hasBoardElection,
    required this.hasEVoting,
  });

  final String symbol;
  final String companyName;
  final String meetingType; // "股東常會" | "股東臨時會"
  final DateTime meetingDate;
  final String? location; // 開會地點
  final bool hasBoardElection; // 是否改選董監
  final bool hasEVoting; // 是否採電子投票

  /// 嘗試從 TPEX ap41_O API 的 JSON 物件解析股東會資料
  ///
  /// 回傳 null 的情況：
  /// - 公司代號為空
  /// - 開會日期無法解析
  static TpexShareholderMeeting? tryFromJson(Map<String, dynamic> json) {
    try {
      final symbol = (json['公司代號']?.toString() ?? '').trim();
      if (symbol.isEmpty) return null;

      final meetingDate = TwParseUtils.parseCompactRocDate(
        json['開會日期']?.toString(),
      );
      if (meetingDate == null) return null;

      final location = json['開會地點']?.toString().trim();

      return TpexShareholderMeeting(
        symbol: symbol,
        companyName: json['公司名稱']?.toString() ?? '',
        meetingType: json['股東常(臨時)會']?.toString() ?? '',
        meetingDate: meetingDate,
        location: (location != null && location.isNotEmpty) ? location : null,
        hasBoardElection: json['是否改選董監']?.toString() == '是',
        hasEVoting: json['是否採電子投票']?.toString() == '是',
      );
    } catch (e) {
      AppLogger.debug('TPEX', '解析 TpexShareholderMeeting 失敗: ${json['公司代號']}');
      return null;
    }
  }
}
