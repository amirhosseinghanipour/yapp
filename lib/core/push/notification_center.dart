import 'package:flutter/widgets.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

final ValueNotifier<String?> currentOpenChatId = ValueNotifier<String?>(null);
