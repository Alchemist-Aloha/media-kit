import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.alexmercerind/media_kit_video');
  const codec = StandardMethodCodec();

  test(
    'controller initializes without a Flutter frame in the background',
    () async {
      MediaKit.ensureInitialized();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'VideoOutputManager.Create') {
          binding.channelBuffers.push(
            channel.name,
            codec.encodeMethodCall(
              MethodCall('VideoOutput.Resize', {
                'handle': int.parse(call.arguments['handle'] as String),
                'id': 1,
                'rect': {'left': 0, 'top': 0, 'width': 1, 'height': 1},
              }),
            ),
            (_) {},
          );
        }
        return null;
      });
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(binding.framesEnabled, isFalse);
      final player = Player();
      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          vo: 'null',
          hwdec: 'no',
        ),
      );
      addTearDown(() async {
        // Unblock the old frame-dependent implementation when this test fails.
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        binding.handleBeginFrame(Duration.zero);
        binding.handleDrawFrame();
        await controller.platform.future;
        await player.dispose();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });

      await controller.platform.future.timeout(const Duration(seconds: 2));
      await player.pause().timeout(const Duration(seconds: 2));
      await player.play().timeout(const Duration(seconds: 2));
      expect(player.state.playing, isTrue);
    },
    skip: !(Platform.isLinux || Platform.isWindows || Platform.isMacOS),
  );
}
