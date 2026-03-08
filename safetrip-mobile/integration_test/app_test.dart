import 'package:integration_test/integration_test.dart';

import 'flows/flow_1_onboarding.dart' as flow1;
import 'flows/flow_2_trip_create.dart' as flow2;
import 'flows/flow_3_main_screen.dart' as flow3;
import 'flows/flow_4_guardian.dart' as flow4;
import 'flows/flow_5_demo_mode.dart' as flow5;
import 'flows/flow_6_sos_offline.dart' as flow6;
import 'flows/flow_7_settings.dart' as flow7;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  flow1.main();
  flow2.main();
  flow3.main();
  flow4.main();
  flow5.main();
  flow6.main();
  flow7.main();
}
