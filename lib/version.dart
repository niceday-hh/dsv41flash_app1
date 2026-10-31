/// 应用版本信息：发版时与 pubspec.yaml 的 `version: x.y.z+n` 保持同步。
///
/// 设置页、关于页统一读取这里，避免出现「包里是新版本、界面写着旧版本」。
library;

const String kAppName = '鲸记账';
const String kAppVersion = '1.5.8';
const int kAppBuild = 14;
const String kAppVersionLabel = '$kAppVersion+$kAppBuild';

