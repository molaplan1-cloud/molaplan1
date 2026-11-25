// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get sd0a2130950 =>
      'The expected device does not answer at this address – check it (http or https?)';

  @override
  String get sdd5742468b =>
      'Something answers, but not as expected. Try https:// or http:// in front and check the port.';

  @override
  String get s03c0a5192b => 'Address not found';

  @override
  String get sb3ef01a6fa =>
      'Check the spelling. Try the IP address (e.g. 192.168.1.50) instead of a name.';

  @override
  String get s274a753ad6 => 'Device not found at this address';

  @override
  String get s2b503695b6 =>
      'Check that the device is on and that your phone or PC is on the same Wi-Fi. Also check the IP address – it can change, so reserve a fixed address in your router.';

  @override
  String get sff9ca463e3 => 'Device found but the port is closed';

  @override
  String get s1d4f4506de =>
      'Check the port number and that the service (web UI, MQTT or Modbus TCP) is enabled on the device.';

  @override
  String get s8523a9cfd0 => 'Secure connection (https) failed';

  @override
  String get sdfd499c1f1 =>
      'Try http:// instead, or enable \"Allow self-signed certificate\" under Advanced.';

  @override
  String get s3fabccc1cd => 'Login, password or token rejected';

  @override
  String get sdc2d65f8eb =>
      'Check the credentials. In Home Assistant you can create a new long-lived token in your profile.';

  @override
  String get se0a7cef6c4 => 'Device answered but the item was not found';

  @override
  String get see02239a35 =>
      'Check the path or entity name (e.g. light.living_room).';

  @override
  String get sdec83d1e90 => 'The device reported an error';

  @override
  String get s3de239ffc5 => 'Check the path and payload.';

  @override
  String get s6121e8d8f1 => 'Unknown register on the device';

  @override
  String get s3474aedf54 =>
      'Check the register number. If the table starts at 1 (e.g. 40001), subtract 1. Also check holding vs input.';

  @override
  String get s2c303f6774 => 'Register type not supported';

  @override
  String get s945685fcda => 'Try the other register type (holding ↔ input).';

  @override
  String get s07ffbc349a => 'Value rejected by the device';

  @override
  String get s76b95eef9f =>
      'The value is probably out of range. Check the scale too.';

  @override
  String get sb66bc0e677 => 'No Modbus reply';

  @override
  String get s6ef5539bc2 =>
      'Connected but no reply. Check the unit id (often 1) and the gateway serial settings.';

  @override
  String get s17ea4c52d5 => 'No reply from the device';

  @override
  String get s50ecf9ba6f =>
      'Connected but no reply in time. Check the message.';

  @override
  String get sf93db545a1 => 'There is a mistake in the settings';

  @override
  String get sf19a9f0856 =>
      'Check the fields, e.g. that the address starts with http:// and numbers are numbers.';

  @override
  String get s3976954bef => 'This tile has no device';

  @override
  String get sc025e0a1f4 =>
      'Open edit mode (pencil) and choose a device for the tile.';

  @override
  String get s7e11595f9e => 'The home bridge is off';

  @override
  String get s2cd1df086e =>
      'Remote access goes through the bridge at home (tablet or PC). Check that it is on, Molaplan is open and it has internet.';

  @override
  String get sdfb639365a => 'No internet connection';

  @override
  String get sdbf06d05d9 =>
      'Your device cannot reach the Molaplan remote service. Check mobile data or Wi-Fi.';

  @override
  String get s8b737f4026 => 'Remote access was removed';

  @override
  String get s4b9e4ca079 =>
      'This device was removed on the home bridge. Pair again: Settings → Remote access.';

  @override
  String get s5b3116ed94 => 'The home bridge did not answer in time';

  @override
  String get se082095a34 =>
      'The connection may be slow. Try again in a moment.';

  @override
  String get s688a4f4ccb => 'The code is not valid';

  @override
  String get sfa0e226cd0 =>
      'Check the 6 digits on the bridge screen. A code is valid for 10 minutes and works once – press \"Pair a phone\" on the bridge again if needed.';

  @override
  String get sfa5c1fb1ac => 'The bridge did not accept this device';

  @override
  String get s9ad07ab36e =>
      'When pairing with the code, the bridge asks for confirmation – press \"Accept\" there. Or scan the QR code, then no confirmation is needed.';

  @override
  String get sb5c271ae6a => 'Security check failed';

  @override
  String get s3d7ca280db =>
      'The connection could not be verified as safe, so it was not used. Try again with the QR code.';

  @override
  String get s0061b44673 => 'The bridge did not answer';

  @override
  String get sceb894b9b3 =>
      'Accept the device on the bridge screen within 3 minutes, or scan the QR code.';

  @override
  String get s700b0ef4de => 'The connection did not work';

  @override
  String get s53a891e670 =>
      'Check the address and settings and try again. The technical details show the exact reason.';

  @override
  String get sc27533ae83 => 'Saving';

  @override
  String get sdbcb85509b =>
      'Temperature may vary the most (+1 / −2 °C). Biggest savings.';

  @override
  String get s380b20be36 => 'Balanced';

  @override
  String get s66ea783264 => 'Small variation (+1 / −1 °C). A good default.';

  @override
  String get see96226e44 => 'Comfort';

  @override
  String get sb403e00b3d =>
      'Almost even temperature (+0.5 / −0.5 °C). Saves a little.';

  @override
  String get sd86b823895 => 'Sonoff';

  @override
  String get s5f297ec9d8 =>
      'BASIC, MINI, POW, TH, 4CH… in DIY mode, with Tasmota or ESPHome. Tiles are made for you; remote use via the home bridge.';

  @override
  String get s60e829b1b0 =>
      'eWeLink app → device → Settings shows the IP address, or your router\'s device list. In DIY mode you also need the Device ID (10 characters).';

  @override
  String get s6a46e8954d =>
      'A Sonoff in DIY mode only answers when told its Device ID. Find it in the eWeLink app: device → Settings → Device ID. Tasmota: the web password, if set.';

  @override
  String get sea057f1a02 =>
      'Only in DIY mode when the search did not find the device.';

  @override
  String s08d04d58a9(String p0) {
    return 'Channel $p0';
  }

  @override
  String get s8653f173b6 => 'Temperature';

  @override
  String get s9cb8820285 => 'Humidity';

  @override
  String get s4899323b9a => 'Power';

  @override
  String get se78754330c => 'power';

  @override
  String get s1a4eab1f51 => '°C';

  @override
  String get s9e731440d8 => '%';

  @override
  String get s77c638e731 => '%';

  @override
  String get s96abb7f975 => '';

  @override
  String get s91e5760e43 => '';

  @override
  String get s2f76c2abd3 => '';

  @override
  String get sc2b99541c7 => 'Switches and relays';

  @override
  String get sd85dbd8e5e => 'Lights and dimmers';

  @override
  String get s38935a3c66 => 'Covers and rollers';

  @override
  String get s64c6ca7840 => 'Energy meters';

  @override
  String get s662fecdc8d => 'Sensors';

  @override
  String get s027fcbe1b6 => 'Switch';

  @override
  String get sa376ec78ec => 'Light';

  @override
  String get s6814e463b1 => 'Cover';

  @override
  String get s477d8b2c95 => 'Total power';

  @override
  String sdaa374b331(String p0) {
    return 'Phase $p0';
  }

  @override
  String get s32c88e5aa6 => 'Light level';

  @override
  String get sbb26f2192c => 'Battery';

  @override
  String get s57b4effa42 => 'Door / window';

  @override
  String get s66350d8e7a => 'Motion';

  @override
  String get s29045a726e => 'Flood';

  @override
  String get s57c2113aee => 'Smoke';

  @override
  String get se8422f063f => 'Sensor';

  @override
  String get s609cb4c5f9 => 'on';

  @override
  String get s356d822497 => 'off';

  @override
  String get s0b2f7d7c80 => 'open';

  @override
  String get s7009587b85 => 'closed';

  @override
  String get s3b35de231e => 'motion';

  @override
  String get s3dfa789b85 => 'ALARM';

  @override
  String get sd9b6de0a6a => 'Other';

  @override
  String se7520a3990(String p0) {
    return 'asleep – last $p0';
  }

  @override
  String get s3aaacf80d2 => 'offline';

  @override
  String get see129fb410 => 'brightness';

  @override
  String get s5d888c1384 => 'true=Open;false=Closed';

  @override
  String get sd74ad36c31 => 'true=Motion;false=No motion';

  @override
  String get sfa12d7fdd7 => 'true=LEAK!;false=Dry';

  @override
  String get s1f18c0f400 => 'true=SMOKE!;false=OK';

  @override
  String get s0bf7cb1613 => 'Philips Hue';

  @override
  String get se17d4e4197 =>
      'Hue Bridge and its lights (also Zigbee lights paired to it). Pair with the bridge button.';

  @override
  String get sf83a145406 =>
      'In the Hue app: Settings → Hue Bridges → (i) → IP address. Or in your router\'s device list: \"Philips-hue\".';

  @override
  String get s80ee7a25a9 =>
      'Press the big round button on top of the Hue Bridge now. Wait here – it connects by itself.';

  @override
  String get s4dbb677293 => 'unreachable';

  @override
  String get sf50732e8e8 => 'dimmable';

  @override
  String s3832b8c729(String p0) {
    return 'whole room';
  }

  @override
  String get sceabe202da => 'camera_';

  @override
  String get s834e3e8c5d => 'Apple';

  @override
  String get s11d8d321df => 'Apple';

  @override
  String get sceefb34afd => 'Apple';

  @override
  String get s24a447c14c => 'Apple';

  @override
  String get s14418a4f88 => 'Apple';

  @override
  String get saab3e952a6 => 'Apple';

  @override
  String get s7fbbfbf469 => 'Apple';

  @override
  String get s045b27e316 => 'Samsung';

  @override
  String get s2c0aede81e => 'Samsung';

  @override
  String get s7bd2005e15 => 'Google';

  @override
  String get sdcec96b503 => 'Google';

  @override
  String get s49960d413e => 'Google';

  @override
  String get s99e5776a78 => 'Google';

  @override
  String get sea3c963b09 => 'Sonos';

  @override
  String get s1e7b1fc81c => 'Synology';

  @override
  String get s7dc8f4cf35 => 'Synology';

  @override
  String get s161d78d79c => 'QNAP';

  @override
  String get s2512122220 => 'Brother';

  @override
  String get s127258a6f4 => 'Epson';

  @override
  String get s4e31401b4f => 'Canon';

  @override
  String get s933e21c819 => 'HP';

  @override
  String get sb309051c1f => 'HP';

  @override
  String get s6f339c5c37 => 'HP';

  @override
  String get s5f8734f6e4 => 'HP';

  @override
  String get sceb247a904 => 'Xiaomi';

  @override
  String get s10b7b68d6c => 'Huawei';

  @override
  String get s3692c1d592 => 'LG';

  @override
  String get se7d945b970 => 'LG';

  @override
  String get s5a5044b5df => 'Sony';

  @override
  String get sd92d7da7d5 => 'Sony';

  @override
  String get saa909391c3 => 'Philips';

  @override
  String get se39b8c84ab => 'Raspberry Pi';

  @override
  String get sec8808f414 => 'AVM';

  @override
  String get s0e225fb918 => 'TP-Link';

  @override
  String get sb34f35dce5 => 'ASUS';

  @override
  String get s7ea140809c => 'Netgear';

  @override
  String get s284be225b7 => 'Ubiquiti';

  @override
  String get sfbaeb6a17e => 'Ubiquiti';

  @override
  String get sa24e9ce91d => 'MikroTik';

  @override
  String get sa1b725d397 => 'Espressif';

  @override
  String get sdf96423738 => 'Amazon';

  @override
  String get sf253859589 => 'Amazon';

  @override
  String get sec4d80656d => 'Roku';

  @override
  String sb9964cfb3b(String p0) {
    return 'Power $p0';
  }

  @override
  String get sfcb44be1a0 => 'Shelly';

  @override
  String get sa6ff717527 =>
      'Relays and plugs: Pro 4PM, Plus 1PM, Plug S, 2.5… Found automatically, tiles for every channel.';

  @override
  String get sd7e123cd2f =>
      'In the Shelly app: open the device → gear (settings) → Device information → IP address. Or in your router\'s device list: the name starts with \"shelly…\".';

  @override
  String get s5f2b2ca5f5 => 'on now';

  @override
  String get s67f64cd925 => 'off now';

  @override
  String get sd8dfb25d31 => 'Shelly Cloud (no bridge)';

  @override
  String get s350215338a =>
      'Control Shellys through the Shelly cloud from anywhere. You only need the key from the Shelly app.';

  @override
  String get s64037991c2 =>
      'Shelly app → your profile → User settings → Authorization cloud key → Get key. Copy and paste it here.';

  @override
  String get s062b21969d =>
      'Shown on the same page below the key (\"Server URI\").';

  @override
  String get sf30bb5d5e6 =>
      'Usually not needed. If nothing is found: Shelly app → device → settings → Device information → Device ID. Separate several with commas.';

  @override
  String get s252ebed5af => 'Shelly Cloud';

  @override
  String get s25399cd337 => 'Server';

  @override
  String get s246c7a46ff =>
      'Shelly app → User settings → Authorization cloud key → Server URI.';

  @override
  String get s61a2d946a4 => 'Cloud key';

  @override
  String get s9d468f5c64 =>
      'Shelly app → User settings → Authorization cloud key → Get key.';

  @override
  String get sf34c97592f => 'IKEA Dirigera';

  @override
  String get sb38eac6a87 =>
      'IKEA smart hub and its lights and plugs (Zigbee). Pair with the button on the hub.';

  @override
  String get s4e92ab791e =>
      'In the IKEA Home smart app: Settings → Hub → IP address. Or in your router\'s device list: \"gw2-…\" or \"dirigera\".';

  @override
  String get s73824fc3d0 =>
      'Press the action button on the bottom of the Dirigera hub once now. Wait here.';

  @override
  String get sda8d9bf1cd => 'Plug';

  @override
  String get s0185672be7 =>
      'The camera user (usually admin) and the password you set when activating it.';

  @override
  String get s814f4633e3 =>
      'User admin. Imou: the password is the \"Safety code\" on the camera label or the device password.';

  @override
  String get s4450807111 =>
      'The camera user in the Reolink app (usually admin) and its password.';

  @override
  String get s1095c54819 =>
      'Reolink app → camera → Settings → Network → Advanced → Server settings: turn on HTTP and RTSP. Battery cameras (Argus) are not supported.';

  @override
  String get sc79a5fee2b =>
      'Tapo app → camera → Advanced settings → Camera account. Create a user and password there and type them here (not your Tapo cloud login).';

  @override
  String get s174e06b97c =>
      'First create a camera account: Tapo app → camera → Advanced settings → Camera account.';

  @override
  String get s21da6fb5dc =>
      'User admin; the password is the 6-letter verification code on the camera label.';

  @override
  String get s1866ef6dc8 =>
      'Ezviz app → camera → Settings → LAN Live View / RTSP: turn it on (if the option exists).';

  @override
  String get s1c2786e15f =>
      'The camera user and password (often admin). ONVIF may need to be enabled in the camera settings.';

  @override
  String get s32270de47a => 'Security camera';

  @override
  String get s4d3ff251d6 =>
      'Hikvision, Dahua, Reolink, Tapo, Ezviz or any ONVIF camera. Picture on a tile, live video at home.';

  @override
  String get se8ea97c5eb =>
      'In the camera app (device info) or your router\'s device list.';

  @override
  String get s1577068729 => 'camera';

  @override
  String get seeb6c38c8e => 'Camera';

  @override
  String get s136c6f0d2b => 'Picture on the tile, live video at home';

  @override
  String get s2101774157 => 'Live video at home (no picture away)';

  @override
  String get sb662db81d8 =>
      'The address looks incomplete. Use four numbers with dots, e.g. 192.168.1.50.';

  @override
  String s738ecfe2bc(String p0) {
    return ' Did you mean $p0?';
  }

  @override
  String s06e738bf27(String p0) {
    return 'This is not a home network address (they usually start with 192.168.).$p0';
  }

  @override
  String sbae99909c4(String p0) {
    return 'Note: this device is on $p0.x – the device may be on another Wi-Fi.';
  }

  @override
  String get s5b44cbe9c0 => 'Home';

  @override
  String get s5a40f12b6a => 'Add';

  @override
  String get s58aaa6dade => 'The view is locked';

  @override
  String get sdf1af3409c => 'Unlock';

  @override
  String get s4629a1695c => 'Menu';

  @override
  String get s41c3cebc48 => 'Add device';

  @override
  String get scd04aa5d9e => 'Edit the view';

  @override
  String get s49de879696 => 'Energy';

  @override
  String get s1da81fd6c3 => 'Settings';

  @override
  String get s365492a7d0 => 'Lock the view';

  @override
  String get sb2f38410ee =>
      'Devices can still be controlled, but editing, settings and adding devices are hidden. Unlock from the gear icon.';

  @override
  String get se497d27174 => 'PIN code (optional)';

  @override
  String get sd21180a166 => 'Without a PIN one tap unlocks.';

  @override
  String get s809d0eb368 => 'Cancel';

  @override
  String get sd86ff8e28a => 'Lock';

  @override
  String get s872f93a062 => 'Unlock?';

  @override
  String get s0cd88e27f4 => 'Editing and settings become visible again.';

  @override
  String get sa5283191be => 'Unlock';

  @override
  String get sdfc012fb4e => 'PIN code';

  @override
  String get sca710b76b5 => 'Wrong PIN code';

  @override
  String sa0c07ccd04(String p0) {
    return 'You have the latest version ($p0).';
  }

  @override
  String get sa118d84538 =>
      'Could not check for updates right now. Check the internet connection and try again later.';

  @override
  String s9f2b092d8c(String p0) {
    return 'Version $p0 is available';
  }

  @override
  String sa5133b2c4a(String p0) {
    return 'You have version $p0.';
  }

  @override
  String get se099b5797e => 'What\'s new:';

  @override
  String get s9315c3df42 => 'Skip this version';

  @override
  String get sdd5c8f0a9d => 'Later';

  @override
  String get sfbf490ec3f => 'Update';

  @override
  String get s5a94ef2af1 => 'The download was corrupted';

  @override
  String get s81e4325573 => 'Download failed';

  @override
  String get s4b1d3df588 =>
      'The file checksum did not match, so nothing was installed. Please try again in a moment.';

  @override
  String get s0c463c7069 =>
      'Check the internet connection and try again. You can also download the update from the release page.';

  @override
  String get s5dd4c9671f => 'Open release page';

  @override
  String get s49ddc3c3b6 => 'Update downloaded';

  @override
  String s04a05bb8fc(String p0) {
    return 'The file is verified and saved:\n$p0\n\nTo use it:\n1. Close Molaplan.\n2. Extract the zip over the old Molaplan folder (or into a new folder).\n3. Start molaplan.exe. Your settings are kept.';
  }

  @override
  String get s1dd246ec69 => 'Release page';

  @override
  String get s0f07b20d45 => 'Open zip';

  @override
  String get s6e1ebc8baa => 'Open folder';

  @override
  String get sa065e7f650 => 'Allow installing updates';

  @override
  String get sdc3bf71baf =>
      'Android asks once for permission so Molaplan can install its own updates.\n\n1. Tap \"Open settings\".\n2. Turn on \"Allow from this source\".\n3. Come back and tap \"Update\" again.';

  @override
  String get sa1bd8d2533 => 'Open settings';

  @override
  String get s441683b7a8 => 'Verifying…';

  @override
  String get se83b7fb2ac => 'Downloading update…';

  @override
  String s0b68f81d82(String p0) {
    return 'Molaplan $p0 is available. The bridge keeps working.';
  }

  @override
  String get sb06bee9921 => 'Show';

  @override
  String get sf1b5d0ffa6 =>
      'The password does not match. Type your account password.';

  @override
  String sd0219ce512(String p0) {
    return 'The connection did not work: $p0';
  }

  @override
  String get sbf59e43c36 =>
      'No internet connection. Check Wi-Fi or mobile data and try again.';

  @override
  String get s9ba7e7a8e6 =>
      'Wrong email or password. Check them, or tap \"Forgot password\".';

  @override
  String get se899b438b5 =>
      'The email is not confirmed yet. Look for the code in your email.';

  @override
  String get s3fb651ebf3 =>
      'This email already has an account. Sign in instead.';

  @override
  String get s1eddf46047 => 'The password must be at least 8 characters.';

  @override
  String get sca19a10c02 => 'That does not look like an email address.';

  @override
  String get s736463f0d2 =>
      'The code is wrong or expired. Check it or ask for a new one.';

  @override
  String get s4800010fa4 => 'Too many attempts. Wait a minute and try again.';

  @override
  String get sf1a6e42ab0 => 'Your sign-in expired. Please sign in again.';

  @override
  String get sf597621fdd =>
      'Another device changed the setup at the same time. Try again.';

  @override
  String get se16eef219e =>
      'The account service did not answer properly. Try again shortly.';

  @override
  String get s2ab0ff38c1 => 'Your account already has a setup';

  @override
  String get s3ce644ca86 => 'Save this device\'s setup to your account?';

  @override
  String get s43d6286f35 =>
      'This device has its own devices and tiles too. What should we do?';

  @override
  String get sd8a380a86d =>
      'Then the same homes, devices and tiles appear on every device signed in to this account.';

  @override
  String get sec25d10ff5 => 'Cancel and sign out';

  @override
  String get sb7a13da58b => 'Use the account\'s setup';

  @override
  String get sf498dceefb => 'Combine both (recommended)';

  @override
  String get s9542718c6f => 'Save to account';

  @override
  String get sa711c4833e => 'Type your email address.';

  @override
  String get s933dc9caef => 'At least 8 characters.';

  @override
  String get sb3cec3f199 => 'Molaplan account';

  @override
  String get sb24f053a48 => 'Email';

  @override
  String get s976a9f2980 => 'Password';

  @override
  String get sc0f9642fb2 => 'Show password';

  @override
  String get s4d212254bc => 'Code from the email';

  @override
  String get s3b86a618be =>
      'The code arrives in a few minutes. Check the spam folder too.';

  @override
  String get sb35c5ba0fc =>
      'With an account your homes, devices and tiles are the same on all your devices – PC, tablet and phone. The home connection moves to a new device without a QR code.\n\nThe account is optional: without one Molaplan works as before and the setup stays on this device.';

  @override
  String get se697487621 => 'Sign in';

  @override
  String get sec4d25a98e => 'I don\'t have an account – create one';

  @override
  String get s860d0269e0 => 'Sign in with a code sent by email';

  @override
  String get s755639049e => 'Forgot password';

  @override
  String get s4a1671a2cc => 'Create a Molaplan account';

  @override
  String get s75c960f1e5 => 'Choose a password (8+ characters)';

  @override
  String get sea446a95e5 =>
      'The password also protects your device passwords and cloud keys: they are encrypted on this device before saving. Keep it safe.';

  @override
  String get s4508b6c2e0 => 'Create account';

  @override
  String s0ca1377846(String p0) {
    return 'We sent a code to $p0. Type it below.';
  }

  @override
  String get s07e981c940 => 'I already have an account – sign in';

  @override
  String get s2e793f899b => 'Confirm your email';

  @override
  String get s87b6699e12 => 'Confirm';

  @override
  String get s824a7408ab => 'A new code was sent.';

  @override
  String get s317ad443fb => 'No code – send a new one';

  @override
  String get scf7e14661c => 'Back';

  @override
  String get s7d43ee2d5a => 'Create an account or sign in';

  @override
  String get s22c960ff4f => 'Sign in with a code';

  @override
  String get scb167ce8b1 =>
      'Type your email and we send you a code. No password needed. If you have no account yet, one is created and this device\'s setup moves into it.';

  @override
  String get s7d29d1dfbd =>
      'We email you a code. No password needed to sign in.';

  @override
  String get sc350da6f19 => 'Send code';

  @override
  String s23cda12342(String p0) {
    return 'Code sent to $p0.';
  }

  @override
  String get s14d85b9e32 => 'Sign in';

  @override
  String get saa1e3d1f13 => 'Send a new code';

  @override
  String get se1be2ec8e5 => 'Sign in with a password';

  @override
  String get s8c48f847f6 => 'Reset password';

  @override
  String get safd591d9b6 =>
      'We email you a code, then you choose a new password.';

  @override
  String get s6807ac704e => 'New password (8+ characters)';

  @override
  String get sa9b5a0b2df => 'Change password and sign in';

  @override
  String get se10ce6962a => 'Syncing…';

  @override
  String get s94d5ea139c => 'Up to date on all your devices';

  @override
  String get sc6f1932436 => 'Offline – changes sync when back online';

  @override
  String get s16ab688a9b => 'Sync failed – will retry';

  @override
  String get s97d4aa9c1a => 'Not synced yet';

  @override
  String get s40ea946050 => 'Signed in';

  @override
  String get s456721b668 => 'Sync now';

  @override
  String get sa9df24980f =>
      'Device passwords and cloud keys are locked. Type your account password to open them on this device.';

  @override
  String get sd1723cc065 => 'Account password';

  @override
  String get s9e9a059c2f => 'Unlock';

  @override
  String get s8b2b8fdc77 => 'I forgot it – start the passwords over';

  @override
  String get s5ec8009dfd =>
      'Saved to the account: homes, devices, tiles and their order, and the home connection. Device passwords, cloud keys and home connection keys are encrypted on this device with your account password before upload – the server cannot read them.';

  @override
  String get s2ea6f9de12 => 'Change password';

  @override
  String get s7ebd89c416 => 'Sign out?';

  @override
  String get s6c6165d662 =>
      'Homes and tiles stay on this device, but changes no longer reach your other devices.';

  @override
  String get s643325053b => 'Sign out';

  @override
  String get sfd6f965e64 => 'Delete account';

  @override
  String get s37bf90cffe =>
      'Permanently deletes the account and everything stored on the server. This device keeps its own setup.';

  @override
  String get sc523d0f28e => 'Delete account';

  @override
  String get s84fda3e17f => 'Cancel';

  @override
  String get s162a85c6ef => 'Save';

  @override
  String get s02c3403918 => 'Choose a new password.';

  @override
  String get s04ab058029 => 'Password changed.';

  @override
  String get s7c23534562 => 'Start passwords over';

  @override
  String get s5ea3703a0a =>
      'Saved device passwords and cloud keys are lost and must be typed again. Homes and tiles stay. Your sign-in password changes to this new one.';

  @override
  String get s321912ef77 => 'Delete the account permanently?';

  @override
  String s3b0ea9bbc7(String p0) {
    return 'The account $p0 and everything stored on the server is deleted. This cannot be undone.\n\nThis device keeps working without an account.';
  }

  @override
  String get s139d2075b8 => 'Account deleted.';

  @override
  String get sfb4df77773 => 'Give the button a name.';

  @override
  String get s986eb41068 => 'Use Pronto: add dump: pronto to remote_receiver.';

  @override
  String s0d353281af(String p0) {
    return 'Button \"$p0\" added.';
  }

  @override
  String get s8e4e78e067 => 'Learn remote';

  @override
  String get s2acab0eccd => 'Done';

  @override
  String get s608a56ad4b =>
      'Save remote buttons to Molaplan, e.g. \"Turbo\". The blaster needs an IR receiver.';

  @override
  String get sa1aed8855e => 'IR remote';

  @override
  String get sded7fb8520 => 'RF433 remote';

  @override
  String get sc8e312a953 =>
      'RF433 = radio remotes (sockets, awnings, garage doors, fans). IR = infrared (heat pumps, TVs).';

  @override
  String get s63c57060b6 => 'Tap \"Start listening\".';

  @override
  String get s439f6f3869 =>
      'Point the remote at the blaster (under 1 m) and press the button once.';

  @override
  String get sd8667596c3 => 'Name it and tap \"Save as button\".';

  @override
  String get sd5f1a45865 =>
      'IR is one-way: the heat pump does not confirm. Molaplan only shows what it sent. Learning works on the home network.';

  @override
  String get s628dc92a8d => 'Listening… press the remote button';

  @override
  String get s1313eb829d => 'Start listening';

  @override
  String get s619fdf8b5c => 'Code received';

  @override
  String get s6264a40ec6 => 'Button name';

  @override
  String get sc630994fba => 'Shown as the tile title.';

  @override
  String get s09feac6b28 =>
      'ESPHome cannot take new codes over the network. Add this to the device YAML, install it, then save the button:';

  @override
  String get sd6f41faa1d => 'Copy';

  @override
  String get s0a7c7a151a => 'Save as button';

  @override
  String get s29adc71f1c =>
      'CN105 connector on the indoor board. ESPHome: esphome-mitsubishiheatpump.';

  @override
  String get s1d17c9fc6e =>
      'S21 (most wall units) or X50A. Faikin plugs straight in; ESPHome: esphome-daikin-s21.';

  @override
  String get s07767f6a03 =>
      'CN-CNT connector (where Panasonic\'s WLAN adapter goes). ESPHome: esphome-panasonic-ac.';

  @override
  String get s659b742754 =>
      'Toshiba indoor service port. ESPHome: esphome-toshiba_ac.';

  @override
  String get s7c3bf9542b => 'Type the device IP.';

  @override
  String sdfa6aedae8(String p0, String p1) {
    return '\"$p0\" added.';
  }

  @override
  String get sbd2f94e7a4 => 'Heat pump (service port/ESPHome)';

  @override
  String get s49b479c566 =>
      'Best way: a small ESP32 on the indoor unit service port. Unlike IR it is two-way – real state and room temperature.';

  @override
  String get sc95a59f7c6 =>
      'Safety: switch the heat pump off at the mains before opening the indoor unit. It may affect warranty.';

  @override
  String get s7b7121b71e => 'Port by brand';

  @override
  String get s67c1a8a6a3 => 'Steps';

  @override
  String get s2f9c5f3130 => 'Get an ESP32 controller and cable.';

  @override
  String get s2675e49423 =>
      'Flash ESPHome per the project guide. Include \"web_server:\" – Molaplan uses it.';

  @override
  String get scd70d27319 => 'Connect it with the power off.';

  @override
  String get s56b0cb63ea => 'Type its IP below and tap \"Find heat pumps\".';

  @override
  String get sdd1cd7bdd5 => 'ESPHome controller IP';

  @override
  String get sa1e21d236a => 'From the router device list or ESPHome dashboard.';

  @override
  String get s1bef32afe0 => 'Find heat pumps';

  @override
  String get s9aa9bc9679 => 'Device answered but has no climate entity.';

  @override
  String get s3a5c21004e => 'Offline';

  @override
  String get sbc7a87e591 => 'Could not get prices – retrying';

  @override
  String get s3f0837ec84 => 'Could not get the weather – retrying';

  @override
  String get s68cbe596f8 => 'Sign-in expired';

  @override
  String get s156aa7eeb3 => 'Device not responding';

  @override
  String get s7abcbf1107 => 'Server not found';

  @override
  String get sca533b6f25 => 'Home bridge not responding';

  @override
  String get s96ad0dc252 => 'Value not found on device';

  @override
  String get s61cdd7287b => 'Setting missing';

  @override
  String get s57d0940253 => 'Security error';

  @override
  String get sfec025279e => 'Device is offline';

  @override
  String get sa7d212f047 => 'Devices on your home Wi-Fi still work.';

  @override
  String get s24ccd151f2 => 'Retry';

  @override
  String get sc5f54cf3c8 => 'Fill in the key and the server.';

  @override
  String get sb26dad8f73 => 'No devices in the cloud with this key.';

  @override
  String s2c6ce95ec2(String p0) {
    return '$p0 now works through Shelly Cloud.';
  }

  @override
  String s5629901cc4(String p0) {
    return 'Control $p0 away from home';
  }

  @override
  String get s064abc90af =>
      'The device is switched to Shelly Cloud. All its channels, names and tiles stay. Key: Shelly app → your profile → User settings → Authorization cloud key.';

  @override
  String get sf16961256b => 'Server (Server URI)';

  @override
  String s28e10c6870(String p0) {
    return 'Which of these is $p0?';
  }

  @override
  String get s09f5da65e0 => 'Switch to Shelly Cloud';

  @override
  String get sa3a093e55e => 'Heating';

  @override
  String get s8efb99df1d => 'Cooling';

  @override
  String get s0b98d62330 => 'Heat and cool';

  @override
  String get s33831dd49f => 'Off';

  @override
  String get sa61efb9866 => 'heating';

  @override
  String get s9a47ee3e3c => 'cooling';

  @override
  String get s156712ac0c => 'idle';

  @override
  String get s8a1f52a37b => 'Thermostat removed';

  @override
  String get s28dc9bc46a => 'No temperature reading';

  @override
  String get s4f1166fe24 =>
      'No home bridge: the thermostat is not controlling yet. Set up remote access on the home tablet.';

  @override
  String get s29fd8d5b5e => 'Now';

  @override
  String get see9111ba68 => 'Relay or switch (on/off)';

  @override
  String get seaed91ad78 => 'Heat pump or AC (setpoint)';

  @override
  String get sb757921c13 => 'Heats';

  @override
  String get s7407864734 => 'Cools';

  @override
  String get s272aa3f1da => 'Both';

  @override
  String get sdadb6e3501 => 'Backup heater';

  @override
  String get se4e381334d => 'Starts only when it is clearly below the target.';

  @override
  String get s17c79c5f4e => 'Power on/off (optional)';

  @override
  String get s92d88612de => 'Heat mode button (optional)';

  @override
  String get s75ac845bab => 'Cool mode button (optional)';

  @override
  String get se12fc46923 => 'None';

  @override
  String get sc590a09db9 => 'What heats or cools?';

  @override
  String get sa15ffe53d4 =>
      'Pick one or more. E.g. a heat pump and a backup heater.';

  @override
  String get sd47a7615a7 => 'No suitable devices yet';

  @override
  String get s3c7649a7f0 =>
      'First add a relay (e.g. Shelly) or a heat pump (IR or service port), then come back.';

  @override
  String get see513572ea => 'Where is the temperature read from?';

  @override
  String get s5155522e83 =>
      'Pick a thermometer. Several = fallback or average.';

  @override
  String get s581fa290f3 =>
      'Optional: the heat pump measures itself. Pick a sensor to see the temperature.';

  @override
  String get s7e4d8d60a0 => 'No thermometer';

  @override
  String get s0787d80876 => 'First add a device that shows a temperature.';

  @override
  String get s89661203b7 => 'First working';

  @override
  String get s0da3005956 => 'Average';

  @override
  String get s0c6a008ffd => 'Name and mode';

  @override
  String get sb1924acbe7 => 'Name';

  @override
  String get s1790a71e85 => 'e.g. Living room';

  @override
  String get sd5f46903a1 => 'Target temperature';

  @override
  String get s6de95e582f => 'If the temperature is lost';

  @override
  String get s8ff25225b4 => 'Switch heating/cooling off (safest)';

  @override
  String get s17cb86f49e => 'Keep as it is';

  @override
  String get sf4caddf894 => 'Advanced';

  @override
  String get s9624f070ee => 'Hysteresis';

  @override
  String get sf070be2c1e => 'Deadband (heat/cool)';

  @override
  String get s64540136ff => 'Minimum on time';

  @override
  String get s21713a2177 => 'Minimum off time';

  @override
  String get s8f7c8eb7d0 => 'Backup heater when below target by';

  @override
  String get sf1eb3b2d34 => 'Sensor lost after no reading for';

  @override
  String get s0ab1430151 => 'New thermostat';

  @override
  String get sbbc98d573d => 'Edit thermostat';

  @override
  String get s6c3e76828b => 'Next';

  @override
  String get s187d328bb1 => 'Edit';

  @override
  String get sc1845eb440 => 'Delete';

  @override
  String get s87984716cb => 'Delete the thermostat?';

  @override
  String get s79786b9f7d => 'Target';

  @override
  String get sdd309c0a63 => 'The thermostat runs on the home bridge';

  @override
  String get s9c1b5394df =>
      'Set up remote access on the home tablet (Settings → Remote access). Until then it does not control anything.';

  @override
  String get s06cda8c0de => 'Runs on this device (home bridge).';

  @override
  String get s2342536aea => 'Runs on the home bridge.';

  @override
  String get s798f7b2876 => 'Smart heating';

  @override
  String get s2c5993c1fd =>
      'Pre-heats before expensive electricity and cold weather, and lets the temperature drop a little in expensive hours.';

  @override
  String get s81c4abc1a5 => 'Overheat +';

  @override
  String get sdea18b2b40 => 'Underheat −';

  @override
  String get s523214c8db =>
      'Line = target temperature, bars = electricity price, dashed = outdoor temperature.';

  @override
  String get s94b8f63aa7 => 'Add the home location for the weather';

  @override
  String get s941fbb47fe => 'Calculating the plan…';

  @override
  String get s702ca14235 => 'Tasmota device';

  @override
  String get se0e5f715ad => 'ESPHome device';

  @override
  String get s63b6e55469 => 'HomeKit device';

  @override
  String get s13e301a66e => 'Unknown device';

  @override
  String get sddb2c2cb2b => 'Phone';

  @override
  String get s16cd267576 => 'Tablet';

  @override
  String get sec4679ec39 => 'Computer';

  @override
  String get s798f9a0558 => 'Printer';

  @override
  String get s06109b8e5c => 'TV / media player';

  @override
  String get sc4655d321e => 'Speaker';

  @override
  String get sa9f2f85b3e => 'Router';

  @override
  String get sf8360dcd74 => 'Network storage';

  @override
  String get s8e21b6f258 => 'Smart device';

  @override
  String get sb38b582dab => 'Home bridge';

  @override
  String get sdf66171e91 => 'This device';

  @override
  String get s76a76a654e => 'iPhone hotspot';

  @override
  String get s15d4ca1672 => 'Phone hotspot';

  @override
  String get sd54522fe39 => 'Router / hotspot';

  @override
  String get s23f4820db7 => 'not controllable yet';

  @override
  String get saae59a3865 => 'via home bridge';

  @override
  String get sdccd6e7f24 => 'Model';

  @override
  String get s891a4b434e => ')\'}';

  @override
  String get s43aba09687 => 'Ports';

  @override
  String get scee3511db6 => 'Sources';

  @override
  String get sbc46a05125 => 'Name the device';

  @override
  String get s1d5ed84aed => 'Remembered on this device.';

  @override
  String get s59622d792b => 'Rename';

  @override
  String get s1169d2d093 => 'Find devices';

  @override
  String get s55b85f29a6 => 'Searching your home network…';

  @override
  String get se9c923ff0b =>
      'Molaplan looks for devices it recognises on your home network.';

  @override
  String get s3ff2220816 => 'No known devices found. Pick the brand below.';

  @override
  String s2a9142dc3e(String p0) {
    return 'Found $p0. Tap to add.';
  }

  @override
  String get s2fc39b0bd7 => 'Search again';

  @override
  String get s0a9acb5af1 => 'Search';

  @override
  String get s9a018b8166 =>
      'You are away: the home bridge searched your home network.';

  @override
  String sf16a25c313(String p0) {
    return 'Other devices on the network ($p0)';
  }

  @override
  String get s9e8430c37b =>
      'Molaplan does not control these. iPhones show their name only while awake.';

  @override
  String get s7f308d40c8 => 'Heating';

  @override
  String get s41de361b3e => 'Cooling';

  @override
  String get s4f7ccb7138 => 'Drying';

  @override
  String get s9b2398228e => 'Fan';

  @override
  String get s533177c689 => 'Idle';

  @override
  String get sa3e8beed42 => 'Heat';

  @override
  String get s6c9668fbd9 => 'Cool';

  @override
  String get sd032c3efec => 'Auto';

  @override
  String get s9db8aefc43 => 'Dry';

  @override
  String get s0117dea8bc => 'Fan';

  @override
  String get s11a7c24b38 => 'No reading';

  @override
  String get s28b7c227f0 => 'set';

  @override
  String get s81e0c3084b =>
      'Could not read the light – control may still work.';

  @override
  String get s7400a53ab2 => 'Colour';

  @override
  String get s09aec1d642 => 'White';

  @override
  String get s16ff3849c9 => 'Colour temperature';

  @override
  String get sf117c88d83 => 'Warm';

  @override
  String get secb1232aad => 'Cool';

  @override
  String get sb2fa876c32 => 'Brightness';

  @override
  String get s34cc93ca61 => 'Favourites';

  @override
  String get sdc485831ad => 'Long-press to remove';

  @override
  String get s3c98732a8c => 'Gauge';

  @override
  String get s6f29aeb685 => 'Trend';

  @override
  String get s3298699c1a => 'Gauge + trend';

  @override
  String get sed593f53ed => 'Value';

  @override
  String get s9027c88cb7 => 'Collecting data…';

  @override
  String get se38a9bb2ed => 'Last';

  @override
  String get s049d71f971 => 'last';

  @override
  String get s55d52c5ae1 => 'This device is not on Wi-Fi';

  @override
  String s9a4dece965(String p0) {
    return 'Connect this device to your home Wi-Fi (the one $p0 uses). Or, if you are away, set up the home bridge so the search runs on a device at home.';
  }

  @override
  String get s3972820cd6 => 'Could not reach the device';

  @override
  String s0f480abb4a(String p0) {
    return 'Could not reach the device at $p0';
  }

  @override
  String sa82143ee02(String p0, String p1) {
    return '1. Check that $p0 is powered.\n2. This device (or the home bridge) must be on the same Wi-Fi.\n3. Check the address – it can change. Tap \"Back\" and search again.';
  }

  @override
  String get sd4d7ad1bab => 'A different device answered';

  @override
  String s5b7d02a301(String p0) {
    return 'The device at that address is not $p0. Check the address.';
  }

  @override
  String get sdac5622fa8 => 'The device asks for a password';

  @override
  String get sbf9ee8aaec =>
      'A password is set on the device. Type it below and tap \"Connect\".';

  @override
  String get s9e22388413 => 'One more detail is needed';

  @override
  String sc8702d4da2(String p0) {
    return '$p0 does not tell this by itself. Type it below and tap \"Connect\".';
  }

  @override
  String get s83f57c7c24 => 'Wrong password';

  @override
  String get s32e85a0ba2 =>
      'Check the password (case matters). You can change it in the device app.';

  @override
  String get sb1d36bfdd3 => 'The button was not pressed in time';

  @override
  String get sc994f6ec6e =>
      'Tap \"Try again\" and then press the button right away.';

  @override
  String get s663202243e => 'Nothing to control was found';

  @override
  String get sb03997d94b =>
      'The device answered but has no switches or lights. For the cloud, type the Device ID.';

  @override
  String get s869571042f => 'Cloud key or server not accepted';

  @override
  String get sab1763c592 =>
      'Copy the key and server again from the Shelly app (User settings → Authorization cloud key).';

  @override
  String get s855ffbfd24 => 'Could not reach the cloud';

  @override
  String get s739d569a9c => 'Check the internet connection.';

  @override
  String get sc96a3502b5 => 'Too many requests';

  @override
  String get sed917dc2a2 => 'The cloud limits requests. Wait a moment.';

  @override
  String get s516dbdd784 => 'The home bridge is out of date';

  @override
  String get s70089507bf =>
      'Update Molaplan on the bridge (Settings → Check for updates).';

  @override
  String get scc1918f2dc =>
      'Check that the bridge at home is on, Molaplan is open and it has internet.';

  @override
  String get se11f9b5084 => 'Could not connect to the device';

  @override
  String get s979376dca6 =>
      'Check the address and that the device is on, then try again. The technical details show the exact reason.';

  @override
  String get sce6d01c270 => 'Type the address first';

  @override
  String get s65bbf3cab4 => 'Check the address';

  @override
  String sb711cc1ce2(String p0, String p1) {
    return '$p0 is not a home network address. They usually start with 192.168. – check it again in the $p1 app.';
  }

  @override
  String se60794c266(String p0) {
    return 'Did you mean $p0?';
  }

  @override
  String get s264fda2dee => 'I\'ll fix it';

  @override
  String get s0a6098ac78 => 'Try anyway';

  @override
  String sc1039f5cf6(String p0) {
    return 'Use $p0';
  }

  @override
  String get s20f777bfef => 'The address is on another network';

  @override
  String sbb1730fa00(String p0, String p1, String p2, String p3) {
    return 'Address $p0 is not on the same network as this device ($p1.x). Usually this device is on a different Wi-Fi than $p2.\n\nJoin the same Wi-Fi, or set up the home bridge.';
  }

  @override
  String get s43370d968c => 'Fill in first';

  @override
  String get s915c9a0db3 => 'Pick at least one';

  @override
  String sb160156a36(String p0) {
    return 'Add: $p0';
  }

  @override
  String get s43d448a950 => 'Add to home view';

  @override
  String get sd890121a57 => 'Show home view';

  @override
  String get sb1717cc67c => 'A) Without a home bridge';

  @override
  String get s2082568a23 => 'Use Shelly Cloud (no bridge)';

  @override
  String get s5080d486b8 =>
      'Best if no device always stays at home – e.g. your tablet travels with you. Control goes via Shelly\'s own cloud. You need a key from the Shelly app (we show where).';

  @override
  String get s82985d5078 => 'B) Through a home bridge';

  @override
  String get s78aec2034d => 'How will you control your home when away?';

  @override
  String s03b3c3b3c8(String p0) {
    return 'A home bridge is a device that ALWAYS stays at home, switched on and on the same Wi-Fi as $p0 – e.g. an old phone, tablet or PC. Your other devices reach it over the internet (encrypted, no port forwarding). A device you carry around is not a good bridge.';
  }

  @override
  String get s688d1308d7 =>
      'As you are signed in, the home connection reaches all your devices automatically.';

  @override
  String get s96feb2f60a =>
      'This device always stays home – make it the bridge';

  @override
  String get sb2a33a1ec4 =>
      'Keep it charging with Molaplan open. Other devices connect with a QR code or by signing in to the same account.';

  @override
  String get s1b9f4ae6d5 => 'The bridge is on another device – connect to it';

  @override
  String get s13d739b710 =>
      'Scan the bridge QR code. Devices are then found through the bridge, even when you are away.';

  @override
  String get sda6a1e50e9 =>
      'Skip for now – add on the home network (remote access can be set up later)';

  @override
  String s6f326a48f9(String p0) {
    return 'Finding: $p0';
  }

  @override
  String get sc788897ba0 =>
      'Searching through the home bridge, so this works away from home too.';

  @override
  String get s0f7361f40c => 'Looking on your home Wi-Fi. Tap yours.';

  @override
  String get sda2b4c9721 => 'Open Wi-Fi settings';

  @override
  String get sc93d9cc14b => 'Connected – search again';

  @override
  String get s13f0596b74 => 'Searching… (about 5 seconds)';

  @override
  String s8eabd27f68(String p0, String p1) {
    return 'Nothing found automatically. Check that $p0 is on and on the same Wi-Fi. You can also type the address below.';
  }

  @override
  String get sa616ab181e => 'Type the address';

  @override
  String get sb439b8abc3 => 'Or type the address';

  @override
  String get s178e07f06b => 'IP address';

  @override
  String get scf487a3699 => 'Where do I find it?';

  @override
  String get s9b9b0d01a2 => ' (optional)';

  @override
  String get s0a7134d0e3 => 'Press the button now';

  @override
  String s43118959d5(String p0) {
    return '$p0 s left';
  }

  @override
  String get sba10f23f03 => 'Connecting…';

  @override
  String get s46c87a553f => 'Sign in to the camera';

  @override
  String get se4095d7d95 => 'Device password';

  @override
  String get sdbdf676485 => 'Connect';

  @override
  String get s200542b930 => 'Try again';

  @override
  String get s8f610a3bb2 => 'I am away from home';

  @override
  String get sf77125583f => 'Technical details';

  @override
  String s77ec7b376b(String p0) {
    return 'Found: $p0';
  }

  @override
  String get sac4debdb9c => 'Pick what goes on the home view and name them.';

  @override
  String get sfe5661e401 => 'Select none';

  @override
  String s2618555da0(String p0) {
    return 'Select all ($p0)';
  }

  @override
  String get s86c3f92546 => 'Also add brightness / power';

  @override
  String get s91571486e4 => 'Also show power (W)';

  @override
  String sf86536db42(String p0) {
    return 'Done! $p0 tiles added';
  }

  @override
  String get sbfaea66122 =>
      'The tiles work at home and away through the cloud – nothing else to do.';

  @override
  String get se7c68b3bed =>
      'The tiles work at home and away through the home bridge – nothing else to do.';

  @override
  String get sbc8469cce1 =>
      'The tiles work on your home network. To control from anywhere, set up the home bridge.';

  @override
  String get s856a422504 => 'Set up remote access';

  @override
  String get sd9923cda70 => 'Not at home? Turn on remote access';

  @override
  String get s876c7230a2 => 'Add a device';

  @override
  String get s1e593aeca2 => 'Close';

  @override
  String get s3d00dee1a9 => 'Use';

  @override
  String get sa252f06bff =>
      'Pick your device brand. Molaplan finds it and creates the tiles.';

  @override
  String get s5b3b5e5a24 => 'Search brand or device (e.g. Shelly, Hue, IKEA)';

  @override
  String get sa427be10c9 => 'Find and connect automatically';

  @override
  String get s6f4cc0844f => 'Coming – how to use it today';

  @override
  String get s846ee3bc67 => 'Other devices';

  @override
  String get sdeadd78d47 => 'Thermostat heating cooling';

  @override
  String get s48264cfe32 => 'Thermostat';

  @override
  String get s641a848754 =>
      'Keeps the temperature you want: controls relays or a heat pump from a thermometer. Can save with spot prices.';

  @override
  String get s94493d01ca => 'Weather forecast temperature rain wind';

  @override
  String get s262f9527aa => 'Weather forecast';

  @override
  String get scb3570338f =>
      'Weather now and hourly: temperature, rain and wind at your home. No device needed.';

  @override
  String get s2a9b6fedd9 => 'Can\'t find your brand?';

  @override
  String get scfc7244d06 =>
      'Husqvarna, Zigbee, Tuya, heat pumps… see how to use them today.';

  @override
  String get sf7b77783e5 => 'Other (manual setup)';

  @override
  String get sc168355ee6 => 'Other device (advanced)';

  @override
  String get s3022f72ece => 'All connection types.';

  @override
  String get s2d1d488d6d => 'For technical users.';

  @override
  String get s6f1c11270c => 'Contains example settings';

  @override
  String s1ea8fe913b(String p0) {
    return 'Address: $p0';
  }

  @override
  String get s16dc13070c =>
      'Home Assistant uses a self-signed certificate. It was accepted because the address is on the home network.';

  @override
  String get sd531eb2fc2 =>
      'Home Assistant was not found automatically. Type the address you open it with (e.g. http://192.168.1.20:8123 or the Nabu Casa address).';

  @override
  String get s7def041e83 => 'Found Home Assistants:';

  @override
  String s2967a37e01(String p0, String p1) {
    return 'Found: $p0 – $p1';
  }

  @override
  String get s8f4c0baf1a =>
      'No devices found automatically. Type the address yourself – find it in your router or the device app.';

  @override
  String get s104238f11e => 'Found devices – pick yours:';

  @override
  String get sd5f9dce947 => 'Search is not available on this network.';

  @override
  String get s26abc57d91 => 'Teach remote buttons?';

  @override
  String get sc709f38633 =>
      'Basic control works already. You can also teach other remote buttons, e.g. \"Turbo\".';

  @override
  String get s6cac83dd5e => 'Not now';

  @override
  String get s97ea2eeb11 => 'Teach now';

  @override
  String get s09cfb7b2a1 => 'Device added';

  @override
  String sda9574390f(String p0) {
    return 'Device and $p0 tiles added';
  }

  @override
  String get sd51ee1ec8d =>
      'Preset settings are examples. Check them against your device manual before relying on them.';

  @override
  String get s566585dc66 =>
      'IR is one-way: the heat pump does not confirm. Molaplan always sends the whole state and shows what it sent. Learn other remote buttons later: Connections → blaster → \"Learn remote\".';

  @override
  String get s0dd21e026c => 'Guide and automatic search';

  @override
  String get s695a011cc1 => 'Searching…';

  @override
  String get s47d409fddd => 'Search network';

  @override
  String get s7196b72140 =>
      '⚠ No native Modbus TCP – an RS485 → TCP gateway is needed.';

  @override
  String get s2e8ba44677 => 'Source';

  @override
  String get sceb8e47d07 => 'Test connection';

  @override
  String get s02ce5f4a01 => 'Works!';

  @override
  String get sb9e9e55164 => 'These tiles will be created';

  @override
  String get s1cb2891ef2 =>
      'Fill in the fields marked with * to see the tiles.';

  @override
  String get s504861ee78 =>
      'No ready tiles – you can add them later with the pencil button.';

  @override
  String get s1094266d4c => 'Shows a value';

  @override
  String get sf6ae3f3323 => 'On/off switch';

  @override
  String get s20dad69675 => 'Button';

  @override
  String get s0e9f94df05 => 'Slider';

  @override
  String get s109b454866 => 'Camera view';

  @override
  String get s37153e0e80 => 'Advanced settings';

  @override
  String get s0ca55a9cae =>
      'Other devices use technical settings (HTTP, MQTT, Modbus…). If your brand is listed, use it instead.\n\nTurn on advanced settings? You can turn them off in Settings.';

  @override
  String get s9630135746 => 'Turn on';

  @override
  String get sbcdff8f72a => 'Which camera do you have?';

  @override
  String get s67bf18fb6f => 'Other camera (ONVIF)';

  @override
  String get s772c158a57 => 'tcp';

  @override
  String get sea00017814 => 'low-latency';

  @override
  String get s2d65587b87 => '8';

  @override
  String get s2ad22696ca => 'Language';

  @override
  String get s7efc5653d2 => 'Device language';

  @override
  String get s4529c1010a => 'Choose a camera connection';

  @override
  String get s98bf81bba3 => 'Live video does not work on this device';

  @override
  String get seb2bb5cbce =>
      'Live video shows only on the home network. This camera has no still picture for remote use.';

  @override
  String get sc95fb5440b => 'Stream ended';

  @override
  String get sd55dd196f6 =>
      'No live video. Check that you are on the home network and RTSP is on in the camera.';

  @override
  String get s8e574c3313 => 'Power';

  @override
  String get sa9360bdda1 => 'Fan';

  @override
  String get sc7d02fbe84 => 'Heat pump';

  @override
  String get s8d06ee5308 => 'Alarm';

  @override
  String get sfb63e3c23f => 'Lock';

  @override
  String get s2f42d90475 => 'Water';

  @override
  String get sf2d10dd213 => 'Electricity / power';

  @override
  String get s291ca127d6 => 'Garage';

  @override
  String get sb543af1c63 => 'Door';

  @override
  String get s60b1079d6c => 'Window';

  @override
  String get s66ce56ca38 => 'Start';

  @override
  String get s0ab3a44562 => 'Timer';

  @override
  String get s3044a10005 => 'Network';

  @override
  String get s1f67139f55 => 'Sauna / heating';

  @override
  String get sf21fd72396 => 'Outlet';

  @override
  String get s7783fe5fca => 'Favourite';

  @override
  String get s912ea5d2ec => 'Send';

  @override
  String get se223375393 => 'List';

  @override
  String get sfb0b971c01 => 'Swing';

  @override
  String get see42f2d999 => 'Remote';

  @override
  String get s9126bf24a0 => 'Sun';

  @override
  String get s306729fe62 => 'No prices';

  @override
  String get s80c4ecec94 => 'c/h';

  @override
  String get sbfe79d1f5f => 'Updated';

  @override
  String get sb68e905fc4 => 'Usage (kWh)';

  @override
  String get s5fc5085143 => 'Cost';

  @override
  String get s2b2118a93b => 'Old data';

  @override
  String get sb730159a01 => 'Price now';

  @override
  String get s68fcfcfed1 => 'Cheapest hour today';

  @override
  String get s86ff059f5e => 'Average today';

  @override
  String get s7b911d48c6 => 'Priciest hour today';

  @override
  String get s29dbf49d92 => 'Instant cost';

  @override
  String get s723c887da6 => 'min';

  @override
  String get s3b36524e04 => 'avg';

  @override
  String get scaaff6345d => 'max';

  @override
  String get s5f131c3ec4 => 'Usage';

  @override
  String get s039bb374fe => 'Figures are hourly averages';

  @override
  String get sa5e6b1e0e3 => 'Tomorrow after ~14:00';

  @override
  String get s62cfd94468 => 'Cheapest hours at night';

  @override
  String get s7995dff292 =>
      'On during the cheapest night hours (22–07). Good for water heaters and EV charging.';

  @override
  String get sf92675687a => 'Cheapest hours of the day';

  @override
  String get sf71a753c59 => 'On during the cheapest hours of the day.';

  @override
  String get s6c070f7367 => 'Off when electricity is expensive';

  @override
  String get s214f034099 =>
      'Turns off above the limit and back on when the price drops.';

  @override
  String get s3939cfc37e => 'On when electricity is cheap';

  @override
  String get scecc366bc4 => 'On only when the price is below the limit.';

  @override
  String get s6e700ae773 => 'Price control removed';

  @override
  String get s5aa3400a7a => 'Price control saved';

  @override
  String get s2f5410429b =>
      'The rule runs on this device (home bridge). Keep it on at home.';

  @override
  String sb86a43361f(String p0) {
    return 'The rule runs on the home bridge – your phone can be off.';
  }

  @override
  String get s4e35ba5321 =>
      'No home bridge yet. The rule is saved but runs only once an always-on tablet or PC at home is the bridge (Settings → Remote access).';

  @override
  String s1a9e9bead3(String p0) {
    return 'Price control: $p0';
  }

  @override
  String get s6b609c3376 => 'When should it be on?';

  @override
  String get s93e5435cf4 => 'No price control';

  @override
  String get s55e5c3a177 => 'How many hours on';

  @override
  String get s52ef5e0b45 => 'Price limit';

  @override
  String get s993193d056 => 'Upcoming on-times';

  @override
  String get s2f7c00a89e => 'Prices unavailable right now.';

  @override
  String get s406e599999 =>
      'No on-times in the next day (or tomorrow\'s prices are not out yet).';

  @override
  String get s140acccb81 => 'Today';

  @override
  String get s0de6e75a52 => 'Tomorrow';

  @override
  String sf87d92faf4(String p0, String p1) {
    return 'Price area $p0. Day-ahead spot prices incl. VAT $p1 %. Add the \"Electricity price\" device to change area and fees.';
  }

  @override
  String get s2adc3a77ed => 'Choose connection type';

  @override
  String get s78d94155f1 => 'Connections';

  @override
  String get s776d8b06bf => 'New connection';

  @override
  String get sc6d89693a5 =>
      'No connections yet. Add a device or service, e.g. ventilation unit (Modbus), Home Assistant or a camera.';

  @override
  String get s07c82cb0af => 'Required field';

  @override
  String get sf702cf0ac6 => 'Delete connection?';

  @override
  String s6b83de0ab9(String p0) {
    return '$p0 tiles use this connection and will stop working.';
  }

  @override
  String get sccd1325381 => 'The connection will be removed from this device.';

  @override
  String get s837e0fc5e6 =>
      'IR is one-way: the heat pump does not confirm commands. Tiles show the last sent state.';

  @override
  String get s09737988fd => 'Connection works!';

  @override
  String get s0a972aa85e =>
      'Passwords and tokens are stored in the device\'s secure storage.';

  @override
  String get sc51b1e0dc0 => 'What do you want to add?';

  @override
  String get s67584c9abf => 'Device';

  @override
  String get s38f5b2ef26 =>
      'Shelly, Sonoff, Hue, camera, heat pump… Searches your home network automatically.';

  @override
  String get s3b56b2cb8d => 'Tile';

  @override
  String get sfc846c4cc5 =>
      'Electricity price, weather, camera, gauge, notification or command – no new device needed.';

  @override
  String get s147f47be4c => 'Add a tile';

  @override
  String get s229f981388 => 'Home bridge on';

  @override
  String get sfc2dc8fc36 => 'Bridge: offline';

  @override
  String get sdedbb30a67 => 'At home';

  @override
  String get s9d64d4c166 => 'Remote';

  @override
  String get s1f8cf57b2c => 'No connection';

  @override
  String get s678a751265 => 'Connect this device to home';

  @override
  String get sdae0305965 =>
      'There is a home bridge (tablet or PC) at home already. Scan its QR code or type the 6 digits.';

  @override
  String get s5f8284b98f => 'Make this device the home bridge';

  @override
  String get s6a95f7843b =>
      'This device stays at home, always on (charger + Wi-Fi), and passes remote commands to your devices.';

  @override
  String get s2c3ae5833b => 'Other ways: VPN, Nabu Casa, cloud MQTT';

  @override
  String get s807e3a32f3 =>
      'Step-by-step guides if you already use Tailscale, WireGuard, Home Assistant Cloud or cloud MQTT.';

  @override
  String get sa3e78d5c4e => 'The home bridge answers – remote access works.';

  @override
  String get s370acd310d => 'Remote access';

  @override
  String get s0b57661c18 => 'Control your home from anywhere';

  @override
  String get sb43ef4094c =>
      'At home Molaplan talks to your devices directly. Elsewhere it goes encrypted through your home bridge – no port forwarding or router settings. The app picks the right path automatically.';

  @override
  String get s075e5a4864 => 'Connected to home';

  @override
  String get sa7679488fb =>
      'At home = directly. Remote = through the home bridge. No connection = neither answers.';

  @override
  String get s19cec9667e => 'Test remote access';

  @override
  String get s86ad95fa48 => 'Copy home dashboards';

  @override
  String get sfaa5185b74 => 'Remove remote access?';

  @override
  String get sbc44ce6993 =>
      'This device can then no longer reach home from outside. You can pair again any time.';

  @override
  String get s9593939a4c => 'Remove';

  @override
  String get s3563cb1635 => 'Remove remote access';

  @override
  String get s528c4f3a4c => 'This device is the home bridge';

  @override
  String get se7b8d659b5 => 'Advanced';

  @override
  String get sfd263f3e04 => 'Camera refresh when remote';

  @override
  String s99249ddf24(String p0) {
    return 'Remotely the camera shows a picture every $p0 s (saves data).';
  }

  @override
  String get s451ea613dd => 'Relay server';

  @override
  String get s72da730a42 => 'Remote service: connected';

  @override
  String get s421f161f5b => 'Connecting to the remote service…';

  @override
  String get s88e2b1dad5 =>
      'No connection to the remote service – retrying automatically. Check the internet connection.';

  @override
  String get scc0cccf89d => 'Off';

  @override
  String get sa1d085d92c => 'The home bridge has no dashboards to copy.';

  @override
  String sa13ef6f8d9(String p0) {
    return 'Copied: $p0 dashboards';
  }

  @override
  String sab5e7202f5(String p0) {
    return 'Connected to \"$p0\"!';
  }

  @override
  String get s30f06b7fb0 =>
      'You can now control your home from anywhere. Copy the home bridge\'s dashboards and devices to this device too?';

  @override
  String get s641263ce18 => 'No thanks';

  @override
  String get sa7a6c0fc2d => 'not a Molaplan code';

  @override
  String get se2ecf1935a => 'Connect to home';

  @override
  String get s410655fd47 => 'How to connect';

  @override
  String get s3a141e0c32 =>
      'On the home bridge (tablet or PC at home) open Molaplan → Settings → Remote access → Make this device the home bridge.';

  @override
  String get sc7c83b2f58 =>
      'Press \"Pair a phone\" there. A QR code and 6 digits appear.';

  @override
  String get s35284509d4 => 'Scan the QR code or type the digits below.';

  @override
  String get s66bb65d8e8 => 'Scan the QR code';

  @override
  String get se97cc157ef => 'or type the code';

  @override
  String get s643434044c =>
      'When using the code, press \"Accept\" on the home bridge too.';

  @override
  String get s9753766742 => 'Press \"Accept\" on the home bridge screen…';

  @override
  String get s50e49dd1df => 'Point the camera at the QR code';

  @override
  String s5d717bb2c5(String p0) {
    return 'Cannot use the camera ($p0). Allow camera access or type the code.';
  }

  @override
  String s7132345f20(String p0) {
    return 'Device \"$p0\" connected!';
  }

  @override
  String get se2e2af02ac =>
      'The home bridge is a device that stays on at home, e.g. an old tablet or a PC. When you are away, your phone\'s commands go encrypted through it to your devices.';

  @override
  String get sd64f52490d => 'Keep it on the charger and on the home Wi-Fi.';

  @override
  String get sbb23f25581 =>
      'Keep Molaplan open. The screen stays on while the bridge is on.';

  @override
  String get sbfed096278 => 'Use this device as the home bridge';

  @override
  String get s13995350ed => 'Pair a phone';

  @override
  String get s6a74454a98 => 'Paired devices';

  @override
  String get s1e4fc2e7fe => 'None yet. Press \"Pair a phone\".';

  @override
  String get s7ea55c5834 => 'Added';

  @override
  String sfd8d693d04(String p0) {
    return 'Remove \"$p0\"?';
  }

  @override
  String get s84572f642e =>
      'The device can then no longer connect remotely. It can be paired again.';

  @override
  String get sc58a7d7121 => 'Home name';

  @override
  String get s9715416100 => 'Scan with the phone';

  @override
  String get sf54c6d871c =>
      'On the phone: Molaplan → Settings → Remote access → Connect this device to home';

  @override
  String get sf7fa9632f3 => 'Valid for';

  @override
  String get s5378bb3f05 => 'Accept this device?';

  @override
  String s1d8bb7b0a6(String p0) {
    return '\"$p0\" wants remote control of your home. Accept only if it is your own or a family member\'s device that just entered the code.';
  }

  @override
  String get sa04c218f82 => 'Reject';

  @override
  String get sdfaf8c242b => 'Accept';

  @override
  String get s1cf33c1fbc => 'Value';

  @override
  String get s86029171be => 'Toggle';

  @override
  String get s4ddce888df => 'Button / shortcut';

  @override
  String get s357fc9c3fe => 'Slider / setpoint';

  @override
  String get s14da6beba5 => 'Shows a reading, e.g. temperature.';

  @override
  String get se4b1d203df => 'On/off, e.g. a light or alarm.';

  @override
  String get sc2197ab417 => 'One tap does one or many things.';

  @override
  String get sd611704caf => 'Adjust a value, e.g. temperature.';

  @override
  String get sacfc0c0b41 => 'Shows a camera image.';

  @override
  String get s7172c54c2c => 'Keeps the temperature at the set value.';

  @override
  String get s76e7a995de => 'Value read';

  @override
  String get sc5edd6d3d1 => 'New tile';

  @override
  String get sa684fd0716 => 'Edit tile';

  @override
  String get s8a8673aafe => 'Title';

  @override
  String get scf37cbeda8 => 'Icon';

  @override
  String get sfeab9bd26f => 'Width';

  @override
  String get s58be670598 => 'Height';

  @override
  String get sd7314e8237 => 'Display';

  @override
  String get s1c72b8c56a => 'Trend length';

  @override
  String get s6bb0c0c7e3 => 'Gauge minimum';

  @override
  String get sa444aab286 => 'Automatic';

  @override
  String get sbf29caff87 => 'Gauge maximum';

  @override
  String get sea30815e6a =>
      'Technical tile settings appear when you turn on \"Advanced\" in Settings.';

  @override
  String get s382afc832f => 'State source';

  @override
  String get s581aee3e96 => 'Optional: where the current state is read from.';

  @override
  String get se6b18b17d9 => 'Poll interval (s, 0 = none)';

  @override
  String get s01f2b1ee0c =>
      'MQTT, Home Assistant and WebSocket update live without polling.';

  @override
  String get s937448ecf5 => 'Test read';

  @override
  String get s5cbdea7f7e => 'Display';

  @override
  String get se6af4b33df => 'Unit';

  @override
  String get sd5498697da => 'Decimals';

  @override
  String get s4f7007db78 => 'Value names';

  @override
  String get s4aae179c52 => '0=Off;1=Home;2=Away';

  @override
  String get s0c12fda7ca => 'Toggle commands';

  @override
  String get s3a9d9e16ef => '\"On\" values (comma separated, empty = auto)';

  @override
  String get s1509c5a2a6 => 'ON command';

  @override
  String get s2a1e131afd => 'OFF command';

  @override
  String get s0201de52c0 =>
      '{{value}} in the command is replaced by the slider value.';

  @override
  String get sc30c9a7e51 => 'Step';

  @override
  String get s4d6451a63a => 'Set command';

  @override
  String get sa4082e1a79 => 'Commands (run in order)';

  @override
  String get s467488e572 =>
      'A shortcut can control several devices in sequence, with delays.';

  @override
  String get sad43973fb3 => 'Add command';

  @override
  String get sdaef43c622 => 'Ask for confirmation';

  @override
  String get s5210a5ad23 => 'Connection';

  @override
  String get s96705fc3df => 'Command sent';

  @override
  String get sb41db1e809 => 'Try';

  @override
  String get s77d2309fd5 => 'Delay before (ms)';

  @override
  String get sc0f5a14d2b => 'Color thresholds (value ≥ limit → color)';

  @override
  String get scd65d31d4c => 'Limit';

  @override
  String get s30a2c0f460 => 'Add threshold';

  @override
  String get s4226eb046f => 'Undo';

  @override
  String get sd5cb601286 => 'Tailscale (easy VPN)';

  @override
  String get s0aa851cfb4 =>
      'Free for personal use. Your phone and home act like one network – Molaplan works with the same addresses as at home.';

  @override
  String get s444ca5d58f =>
      'Good if you have an always-on PC, Raspberry Pi or Home Assistant at home.';

  @override
  String get sec7b4d1d7a =>
      'Create a Tailscale account at tailscale.com (Google, Microsoft or Apple sign-in).';

  @override
  String get s178c57446d =>
      'Install Tailscale on the always-on device at home. In Home Assistant: Settings → Add-ons → Tailscale.';

  @override
  String get s4faf83aa13 =>
      'Turn on \"subnet router\" there and enter your home network, e.g. 192.168.1.0/24. Then all your home devices are reachable.';

  @override
  String get s721719c0e1 =>
      'Approve the route in the Tailscale admin console (Machines → device → Edit route settings).';

  @override
  String get s921f981bda =>
      'Install the Tailscale app on your phone and sign in with the same account. Switch the VPN on.';

  @override
  String get s8ae7e7b2a4 =>
      'Done! Molaplan uses the same addresses as at home. Nothing else to change.';

  @override
  String get se92301ff0a => 'https://tailscale.com/download';

  @override
  String get sf6270ae66c => 'https://tailscale.com/kb/1019/subnets';

  @override
  String get s57f0b61334 => 'WireGuard (router VPN)';

  @override
  String get sb9bb49ab92 =>
      'If your router supports WireGuard (e.g. ASUS, FRITZ!Box, UniFi, OpenWrt), your phone joins the home network directly.';

  @override
  String get s986d264604 =>
      'Good if the router has WireGuard and your connection has a public IP address.';

  @override
  String get sf24b16dc12 =>
      'Open the router settings and look for \"VPN server\" → \"WireGuard\".';

  @override
  String get s1e5d1eb832 =>
      'Enable the server and add a new device (peer) for the phone.';

  @override
  String get s8e0252a2b4 =>
      'The router shows a QR code. Install the WireGuard app on the phone and scan it.';

  @override
  String get s4b3740b727 =>
      'Check that \"Allowed IPs\" includes the home network (e.g. 192.168.1.0/24).';

  @override
  String get sd2e8523b28 =>
      'Switch the VPN on in the phone – Molaplan works as at home.';

  @override
  String get saa17c5a456 => 'https://www.wireguard.com/install/';

  @override
  String get se5960424ea =>
      'Many mobile broadband (4G/5G home internet) connections have no public IP (CGNAT) and WireGuard then cannot be reached from outside. Use Molaplan remote access or Tailscale instead.';

  @override
  String get sab2dfe387b => 'Home Assistant Cloud (Nabu Casa)';

  @override
  String get s2e0586b37e =>
      'A paid monthly subscription from the makers of Home Assistant. Gives a secure remote address to Home Assistant.';

  @override
  String get s534e7ec95e =>
      'Good if your devices are already in Home Assistant.';

  @override
  String get s0f7533967d =>
      'In Home Assistant: Settings → Home Assistant Cloud → start the trial or sign in.';

  @override
  String get s2e60dd8178 => 'Turn \"Remote control\" on.';

  @override
  String get s7a73024451 =>
      'Copy the remote address, which looks like: https://abcd1234.ui.nabu.casa';

  @override
  String get sd4873612f7 =>
      'In Molaplan: Connections → Home Assistant → change the address to the remote address. The token stays the same.';

  @override
  String get s15223b0e32 => 'Done! Home Assistant tiles now work everywhere.';

  @override
  String get s9b3201b1fa => 'https://www.nabucasa.com/';

  @override
  String get s60e7067815 =>
      'This only covers devices controlled through Home Assistant. For others (Modbus, cameras directly) use Molaplan remote access or a VPN.';

  @override
  String get s8e0d0a2d4e => 'Cloud MQTT (e.g. HiveMQ Cloud)';

  @override
  String get sd0fff65292 =>
      'Devices and Molaplan talk through the same cloud server. HiveMQ Cloud has a free tier that is enough for home use.';

  @override
  String get s7350b9f98b =>
      'Good for MQTT devices: Tasmota, ESPHome, Shelly, Zigbee2MQTT, your own ESP boards.';

  @override
  String get s59b3c7d246 =>
      'Create a free account at console.hivemq.cloud and create a free cluster (Free/Serverless).';

  @override
  String get s04fe436d1e =>
      'Under \"Access Management\" create a username and password.';

  @override
  String get sdf0075eab5 =>
      'Copy the server address (e.g. abcd.s1.eu.hivemq.cloud). The port is 8883 with TLS on.';

  @override
  String get s9e9be6fc33 =>
      'Put this server, username and password in your devices\' MQTT settings (TLS on).';

  @override
  String get s90f1cb151b =>
      'In Molaplan: Connections → MQTT → address, port 8883, TLS on, username and password. Done – works everywhere.';

  @override
  String get s77bf29f2f5 => 'https://console.hivemq.cloud/';

  @override
  String get safd2cd2b7b =>
      'Pick a strong password: anyone who knows it can control your devices.';

  @override
  String get s9557c0ef28 => 'Remote access guides';

  @override
  String get sf4d7957b78 => 'Easiest: Molaplan remote access';

  @override
  String get s8032085166 =>
      'No accounts, no router settings. You only need a tablet or PC that stays on at home.';

  @override
  String get sd9b48e01fc => 'Other ways';

  @override
  String get sfe551fd431 => 'Device guides';

  @override
  String get sa35e37b4b4 =>
      'Mitsubishi CN105, Daikin S21/X50A (Faikin), Panasonic CN-CNT, Toshiba. Found automatically.';

  @override
  String get scb28b11e70 => 'New dashboard';

  @override
  String get s1f9799af4e => 'e.g. Cottage';

  @override
  String get s3a13f9d077 => 'Rename dashboard';

  @override
  String get sa5bf37213b => 'Delete dashboard?';

  @override
  String s10671afc00(String p0, String p1) {
    return '\"$p0\" and its $p1 tiles will be deleted.';
  }

  @override
  String s897761b5f4(String p0) {
    return 'Dashboard \"$p0\" deleted';
  }

  @override
  String get scc5cf9957d => 'Choose tile type';

  @override
  String get s7cf6340503 => 'New device with ready tiles';

  @override
  String get se6ca707cf3 => 'Easiest: Shelly, ESP32-CAM, Home Assistant…';

  @override
  String get s0789f5f14f => 'DASHBOARDS';

  @override
  String get sfb3e3c456c => 'Delete dashboard';

  @override
  String get scdfd80f963 => 'Add tile';

  @override
  String get s71af34b8e9 => 'Empty dashboard';

  @override
  String get s6a210970eb =>
      'Your device tiles appear here: temperatures, switches, cameras and shortcuts. Start by adding a device.';

  @override
  String get s4229fb4103 => 'Add your first device';

  @override
  String get sf67e0d5752 => 'Delete tile?';

  @override
  String s97f46743e0(String p0) {
    return 'Tile \"$p0\" deleted';
  }

  @override
  String get sda9203de80 => 'No account – settings only on this device. ';

  @override
  String get s8b3e63da21 => 'Create account ›';

  @override
  String get s887c293cad => 'Device added! 🎉';

  @override
  String get s84a087a679 =>
      'Create an account so your settings are kept and move to your other devices. It only takes an email code, no password needed.';

  @override
  String get s907220900d => 'Welcome to Molaplan';

  @override
  String get s845ec6276f => 'Your setup on all your devices';

  @override
  String get s9dfa93453b => 'Nothing is lost when you change phones';

  @override
  String get s6aa51b28a5 => 'Device passwords are encrypted';

  @override
  String get sc6f02b69d3 => 'Create account / Sign in';

  @override
  String get sc777bde66f => 'With an email code – no password.';

  @override
  String get se2e5ff2c8a => 'Continue without an account';

  @override
  String get sb8934a5835 => 'Electricity use';

  @override
  String get s5409dc748f => 'Not counted';

  @override
  String get sf0bbcc217b => 'Whole site';

  @override
  String get s0ad1897b28 => 'Device meter';

  @override
  String get s99268b5a6c =>
      'Whole site = main meter. Device meter = one device (shown as part of the total, never counted twice).';

  @override
  String get se1174af557 => 'Part of meter (optional)';

  @override
  String get s9773c92c92 => 'Energy and costs';

  @override
  String get s43dead6994 => 'Electricity contract';

  @override
  String get sef4d24cdd4 => 'Day';

  @override
  String get sa62dd794ce => 'Month';

  @override
  String get s6b2ebe5aca => 'Pick your meters first';

  @override
  String get sde41f2fac9 =>
      'Mark below which meter measures the whole site and which ones single devices.';

  @override
  String get s4ad000d885 => 'incl. VAT';

  @override
  String get s9e214b6e88 => 'excl. VAT';

  @override
  String get s73771d252c => 'Measured devices total';

  @override
  String get s22d03356a9 => 'Other use';

  @override
  String get s48b08c5f5a => 'Monthly fees (energy + transfer)';

  @override
  String get s286e1cfb54 => 'Total';

  @override
  String get s2e8700e0cf =>
      'Part of the use had no price (the spot price was missing).';

  @override
  String get sbbd89fbc05 =>
      'Use is recorded while the app is open (all the time on the home tablet).';

  @override
  String get s64382718ff => 'Meters';

  @override
  String get s9a3a0d414e =>
      'No power or energy tiles (W, kW, Wh, kWh). Add e.g. a Shelly meter.';

  @override
  String get sdb0484d728 => 'Saved';

  @override
  String get se80021e22a =>
      'Copy the prices from your bill. Type them with or without VAT – costs are shown both ways.';

  @override
  String get sfb62156afe => 'Price area';

  @override
  String get s1762fb70a7 => 'Energy';

  @override
  String get s2ed3e3cf28 => 'Spot price';

  @override
  String get s5d1dd0f675 => 'Fixed';

  @override
  String get sedb38796fb => 'Night/day';

  @override
  String get s0774cea15a => 'Margin';

  @override
  String get s63370fe61a => 'Energy price';

  @override
  String get s50a7dd89c6 => 'Day energy';

  @override
  String get sdeaa5ad900 => 'Night energy';

  @override
  String get se93c7bcd86 => 'Monthly fee (energy)';

  @override
  String get sb7937e4b91 => 'Transfer';

  @override
  String get s0f89840226 => 'Flat';

  @override
  String get sa768f1b352 => 'Transfer price';

  @override
  String get s9e5dde22cb => 'Day transfer';

  @override
  String get sdf7a4fd2e3 => 'Night transfer';

  @override
  String get s4df0aee067 => 'Monthly fee (transfer)';

  @override
  String get s4c59c90975 => 'Night starts';

  @override
  String get s84decd042b => 'Night ends';

  @override
  String get s90c26f1e37 => 'Taxes';

  @override
  String get s222cb348a0 => 'Electricity tax';

  @override
  String get sbe412dcaa6 => 'VAT';

  @override
  String get s43b55c13c5 => 'Search failed. Check the connection.';

  @override
  String get s171834ca33 => 'Home location';

  @override
  String get s6f6c2fe37a =>
      'The weather forecast (Open-Meteo) helps pre-heat before cold weather. The town is enough.';

  @override
  String get s5f663978d6 => 'Town';

  @override
  String get s7be6460c54 => 'e.g. Tampere';

  @override
  String get s1576b70590 => 'Electricity use, costs, contract and weather.';

  @override
  String get sa6212aaeb4 => 'Location';

  @override
  String get s12c2f8e6e4 => 'Home network only';

  @override
  String s5f7c464e6d(String p0) {
    return 'at $p0';
  }

  @override
  String s21b64ae0a7(String p0) {
    return '$p0 only works on the home network. The tile returns to normal by itself when you are home again.';
  }

  @override
  String get s6b1a8249de => 'Last state';

  @override
  String get s56650a18d5 => 'Make it work remotely ›';

  @override
  String get sa0d8c62e5a => 'No command configured';

  @override
  String get s1e5d696a26 => 'Run this command?';

  @override
  String get s1df6e2eaa7 => 'PIN';

  @override
  String get secab66c046 => 'Remember on this device';

  @override
  String get s10bf4eab8e =>
      'Stored encrypted on this device only. By default the PIN is not stored.';

  @override
  String get s856418521a => 'No commands configured';

  @override
  String sdfa66ee201(String p0) {
    return '$p0: sent';
  }

  @override
  String get s12fc3810a5 => 'Sent – waiting for the reply…';

  @override
  String get sd1c7d49360 => 'Reply at';

  @override
  String get s38ac222392 => 'Value';

  @override
  String get s29fae6a0e8 => 'Price control on';

  @override
  String get s59d55f8882 => 'Rename';

  @override
  String get s25580038cb => 'Saved PIN removed';

  @override
  String get sf50c488b24 => 'Forget saved PIN';

  @override
  String get safe0429a90 => 'Price control';

  @override
  String get sf3d644dd4c => 'Learn a remote button';

  @override
  String get sfb1a18d11f => 'Refresh';

  @override
  String get s4cbe24240f => 'On';

  @override
  String get s72a2328ddd => 'Lights';

  @override
  String get sca12be80ca => 'Switches';

  @override
  String get sa4c0eeea02 => 'Heat pumps and AC';

  @override
  String get sa8dbf04ad3 => 'Binary sensors';

  @override
  String get sa7690acf57 => 'Covers and doors';

  @override
  String get s487bf00fc7 => 'Locks';

  @override
  String get s88ac47e6d1 => 'Cameras';

  @override
  String get sbe76826428 => 'Fans';

  @override
  String get s6b7c1c52da => 'Scenes';

  @override
  String get s9f1334d4e2 => 'Scripts';

  @override
  String get s4b53bcaaf0 => 'Buttons';

  @override
  String get s5c92d42edd => 'Number inputs';

  @override
  String get s3c2ed0c522 => 'Helper toggles';

  @override
  String get se9ca7cb470 => 'Automations';

  @override
  String get sea20d169a3 => 'Media players';

  @override
  String get sbcb95e1e78 =>
      'The token is not accepted. Create a new one in Home Assistant.';

  @override
  String get s0b80dc2642 =>
      'Could not reach Home Assistant. Check the address.';

  @override
  String get sf32b7f15d8 => 'cameras';

  @override
  String s095ca83913(String p0) {
    return '$p0 tiles added';
  }

  @override
  String get sa7a829cefb => 'Pick Home Assistant devices';

  @override
  String get sefdf8e3316 => 'Loading devices…';

  @override
  String get s26583a1933 => 'One view per room';

  @override
  String sf1319d04d0(String p0) {
    return 'Add $p0';
  }

  @override
  String get sb3e6b54bce => 'Search by name or id';

  @override
  String get safedc10c48 => 'All rooms';

  @override
  String get s407f3f7a0c => 'No room';

  @override
  String get sedb7b77645 => 'All';

  @override
  String s140aba8cd7(String p0) {
    return '$p0 lights are Philips Hue lights';
  }

  @override
  String get s16aee2aa30 =>
      'Directly through the Hue Bridge they respond faster and work without Home Assistant.';

  @override
  String get s3816288db1 => 'Add Hue Bridge';

  @override
  String get sa765c9294a => 'Show all';

  @override
  String sdb088f47a8(String p0) {
    return '$p0 technical items hidden (diagnostics, configuration, updates)';
  }

  @override
  String get s3ee8d0a5e3 =>
      'Rooms could not be read – showing devices without rooms.';

  @override
  String get sf55fca7a32 => 'No matches';

  @override
  String get s78cdce874e => 'already added';

  @override
  String get sdc398885dc => 'Advanced settings';

  @override
  String get s5d477f3cd8 => 'Usually you don\'t need these';

  @override
  String get s2315e0e739 => 'e.g.';

  @override
  String get sc1c47d2474 => 'Choose a background picture';

  @override
  String sa8ce5112ee(String p0) {
    return 'At most $p0 background pictures. Remove one first.';
  }

  @override
  String get sceafe9ce2a => 'The file is not a picture';

  @override
  String get s12a7d631af => 'Look';

  @override
  String get s0d83798030 => 'Size';

  @override
  String get s64c916e299 => 'Small';

  @override
  String get s5e3097232a => 'Wide';

  @override
  String get s8971788287 => 'Large';

  @override
  String get s254a1d8e12 => 'Background picture (optional)';

  @override
  String get sc48f5f9bcf => 'Choose picture';

  @override
  String get sf55eee73b8 => 'Change picture';

  @override
  String get sf6723451b9 => 'Take photo';

  @override
  String get sdd957ccc1b => 'Remove picture';

  @override
  String get s7ba9d453ed => 'Dim when the device is off';

  @override
  String get s016ae7b580 =>
      'The picture is shrunk (≤ 200 KB) and synced to your account.';

  @override
  String get sabb10f8cb2 =>
      'The picture is shrunk (≤ 200 KB) and kept on this device only.';

  @override
  String get s4dab2d409b => 'Export configuration';

  @override
  String get s149c1e54d6 => 'Configuration exported';

  @override
  String get s35f445793b => 'Import configuration';

  @override
  String get sd55be829e3 => 'Replace current configuration?';

  @override
  String get s852dd1795e =>
      'All current connections and dashboards are replaced by the file contents.';

  @override
  String get s580678cb10 => 'Import';

  @override
  String get s5f2ec17730 => 'Configuration imported';

  @override
  String get sa87fff54f3 => 'Import failed';

  @override
  String get s2fd2bfedb8 => 'Account';

  @override
  String get s4c0ff416ab => 'The same homes and tiles on all your devices.';

  @override
  String get scc7e418ee3 =>
      'Sign in to have the same homes, devices and tiles on PC, tablet and phone. Optional.';

  @override
  String get s9bb545e9b3 => 'Sign in or create an account';

  @override
  String get s0625d54b38 => 'Tile size';

  @override
  String get s8382da3467 => 'Normal';

  @override
  String get s7c1cd8314e => 'Hide tiles that don\'t work remotely';

  @override
  String get sa0cbbafb4e =>
      'Away from home, tiles that only work on the home network are hidden. By default they stay in place, greyed out.';

  @override
  String get s21f870dbc2 =>
      'Shows technical settings: connections (HTTP, MQTT, Modbus…), payloads, JSON paths and tile sources. Most people don\'t need these.';

  @override
  String get sca4c8b88b7 => 'Home Assistant: add devices';

  @override
  String get saec69088a5 => 'Control your home from outside too.';

  @override
  String get scc3d01ee5e => 'Guides: VPN, Nabu Casa, cloud MQTT';

  @override
  String get s90ba544719 => 'Help';

  @override
  String get sb915c42792 => 'Show the getting-started guide';

  @override
  String get sd337a7ddd5 => 'Backup and transfer';

  @override
  String get s07c1048b4f =>
      'Export the configuration to a JSON file and import it on another device (e.g. PC → phone).';

  @override
  String get s2f797098e7 => 'Include passwords and tokens';

  @override
  String get s26f72949e3 => 'The file is then unencrypted – keep it safe.';

  @override
  String get sdb12678e52 => 'Export';

  @override
  String get s34686ffb09 => 'Example';

  @override
  String get s412c666544 =>
      'Add an example dashboard (camera, alarm, lights, ventilation). Replace the addresses with yours.';

  @override
  String get sec02c7c071 => 'Add example dashboard';

  @override
  String get s522d6584c5 => 'Check for updates';

  @override
  String get sd178a1d809 =>
      'Your own control terminal: HTTP, MQTT, Modbus TCP, Home Assistant, cameras, WebSocket, TCP and UDP. Without an account all settings stay on this device.';

  @override
  String get se455dc672b => 'Step';

  @override
  String get s3ddd2678bf => 'Skip guide';

  @override
  String get s171ac59e67 =>
      'Pick your device below. You only fill in its address – the rest is done for you.';

  @override
  String get se722dfcec9 =>
      'Molaplan is your home\'s own control panel. You put in exactly the devices and buttons you need.';

  @override
  String get scbac938ead => 'See everything at a glance';

  @override
  String get se25f930e31 =>
      'Temperatures, lights, alarm and camera in one view.';

  @override
  String get s3e450dba98 => 'Control with one tap';

  @override
  String get sdda6a3f06e =>
      'Lights on, boost the ventilation, or a \"Leaving home\" button that does many things at once.';

  @override
  String get sbcac0cd35a => 'The same home on all devices';

  @override
  String get sd43d517cc7 =>
      'Sign in if you like, and PC, tablet and phone show the same home. Passwords are encrypted on your device. No account needed.';

  @override
  String get s70fff97e97 => 'I already have a Molaplan account – sign in';

  @override
  String get sd6561a08ca => 'Let\'s start';

  @override
  String get se5be2a8386 => 'Your tiles are ready';

  @override
  String get s8162694dbe => 'Add your first tile';

  @override
  String get s7b2a30b77c =>
      'These tiles were made for your device. You can change and arrange them later.';

  @override
  String get s39e163fa49 =>
      'A tile shows information or controls a device. Choose what kind of tile:';

  @override
  String get s4bfb026e45 => 'I\'ll do this later';

  @override
  String get s3f0351473c => 'Control your home from outside too?';

  @override
  String get s6fe6fe631f =>
      'At home everything works already. From outside you need one always-on device at home (an old tablet or a PC) – no router settings, no accounts.';

  @override
  String get sb599b7432f => 'Remote access is on.';

  @override
  String get s33a294d472 => 'This device is the home bridge.';

  @override
  String get s4aa8cce504 => 'Not now – home only';

  @override
  String get sd3c370ca52 => 'All set!';

  @override
  String get s1359035b73 => 'Tap a tile';

  @override
  String get sfd26c8e50b => 'A switch toggles, a button runs its command.';

  @override
  String get s416c8184a7 => 'Pencil button at the top';

  @override
  String get s2ba275defe => 'Edit, add, delete and drag tiles around.';

  @override
  String get se872eeb0f5 => 'Long-press a tile';

  @override
  String get s63496941fc =>
      'See details and an explanation if something is wrong.';

  @override
  String get s080be778d5 => 'Find this guide, remote access and backups there.';

  @override
  String get sae0fae7127 => 'Go to my dashboard';

  @override
  String get s64f4d1e11a => 'Set the home location';

  @override
  String get sbf7cc3de9a => 'Try now';

  @override
  String get s1becc05ea1 => 'locked=Locked;unlocked=Unlocked;jammed=JAMMED';

  @override
  String get s259de02f33 =>
      'open=Open;closed=Closed;opening=Opening;closing=Closing';

  @override
  String get s64d4364336 =>
      'disarmed=Off;armed_away=Armed;armed_home=Home;armed_night=Night;triggered=ALARM;arming=Arming';

  @override
  String get s5b1e227dc4 => 'on=On;off=Off';

  @override
  String get s3d43664fcc => 'WebSocket';

  @override
  String get sfcbb753f53 => 'URL';

  @override
  String get s81479e1555 => 'Headers (Name: value per line)';

  @override
  String get s5811b38d7b => 'Token (Authorization: Bearer)';

  @override
  String get sd512dbbfc7 => 'Message on connect';

  @override
  String get s2c4fd261e2 => 'Allow self-signed certificate';

  @override
  String get s4d089aab74 => 'Filter (message contains)';

  @override
  String get s55c951a8ad => 'JSON path';

  @override
  String get s10813e25b3 => 'Regex (group 1)';

  @override
  String get s4a282cd247 => 'Request message (sent on read)';

  @override
  String get sbeef545d37 => 'Message ({{value}} = value)';

  @override
  String get s0477f24b6b => 'HTTP / REST';

  @override
  String get s3102ae3a16 => 'Base URL';

  @override
  String get s38d0517a8d => 'Authentication';

  @override
  String get sed995f57b8 => 'Username';

  @override
  String get s65e35b7cc4 => 'Token';

  @override
  String get s51510ae27a => 'Extra headers (Name: value per line)';

  @override
  String get s361419c448 => 'Timeout (s)';

  @override
  String get sf235ce5ec0 => 'Method';

  @override
  String get s484291707c => 'Path';

  @override
  String get s54c8aed8bc => 'Body';

  @override
  String get s5c5e9b662c => 'Body ({{value}} = value)';

  @override
  String get s8e82ca13cf => 'Content-Type';

  @override
  String s3c045f21ee(String p0, String p1, String p2) {
    return 'Tested: GET $p0 (base address, $p1 bytes, $p2 ms).';
  }

  @override
  String get s7797602869 =>
      'No commands were sent and tile paths were not tested.';

  @override
  String sbf349dfcbd(String p0, String p1) {
    return 'HTTP $p0: the device answered but refused the login. Check username, password or token. $p1';
  }

  @override
  String s3bd10f0ae2(String p0, String p1) {
    return 'HTTP $p0: the device answered with a server error. $p1';
  }

  @override
  String s2a7fa26dd6(String p0, String p1) {
    return '✓ The device answered at $p0 (HTTP 404: no page at the base address – normal for many devices). The connection works. $p1';
  }

  @override
  String sb2821916bc(String p0, String p1, String p2) {
    return '✓ Connection works: HTTP $p0. $p1 $p2';
  }

  @override
  String get s58648dc3fc => 'Camera (MJPEG / JPEG / RTSP)';

  @override
  String get s1534821f4a => 'Camera base URL';

  @override
  String get s95533426a3 => 'RTSP address (live video at home)';

  @override
  String get sa1115d4b0b => 'RTSP address, light (tile)';

  @override
  String get se995a6862d => 'Mode';

  @override
  String get s4f356d158a => 'Refresh (s, snapshot)';

  @override
  String get sca7e088857 => 'Electricity price';

  @override
  String get s2525f9a4f5 =>
      'Finland is one area (FI). In Sweden and Norway it depends on where you live.';

  @override
  String get s8f4a683abf => 'VAT %';

  @override
  String get s1c7d76a774 => 'Your country\'s VAT.';

  @override
  String get se49d0fba92 => 'Seller margin (c/kWh)';

  @override
  String get s20a5e2936a => 'Spot contract margin without VAT.';

  @override
  String get s923f9739de => 'Transfer + tax (c/kWh)';

  @override
  String get s2a3498fb0f =>
      'From your bill, incl. VAT. Leave 0 for energy only.';

  @override
  String get s515da3a9dd => 'Price server';

  @override
  String get s98cc9f1c14 =>
      'Molaplan\'s server fetches prices from open sources.';

  @override
  String get s271885dc8b => 'What to show';

  @override
  String get s46282f452b => 'now = current price, chart = today and tomorrow.';

  @override
  String get s2f754e8ab4 => 'No prices for today yet.';

  @override
  String get sd575462da3 => 'tomorrow ';

  @override
  String get s18faad19ed => 'No price for now.';

  @override
  String get s29178b43f4 => 'Electricity price is read-only.';

  @override
  String get s1a707f2788 => 'Tomorrow: yes.';

  @override
  String get sb85af981c1 => 'Tomorrow: not yet (published around 14:00).';

  @override
  String s6270faf138(String p0, String p1, String p2, String p3) {
    return '✓ Prices for $p0 ($p1 slots, $p2 min, source $p3).';
  }

  @override
  String get se1bd60873c => 'MQTT';

  @override
  String get s85b9781bb7 => 'Broker host';

  @override
  String get s800d13debd => 'Port';

  @override
  String get s49fa57061a => 'TLS';

  @override
  String get s0fcef98aad => 'Use WebSocket (ws:// or wss://)';

  @override
  String get s5089c65c1f => 'Client ID (empty = auto)';

  @override
  String get s9372a6f755 => 'Keep alive (s)';

  @override
  String get sd373a99107 => 'State topic';

  @override
  String get s518c8aa712 => 'Command topic';

  @override
  String get s120726c79a => 'Payload ({{value}} = value)';

  @override
  String get s3660228d11 => 'QoS';

  @override
  String get s1b07c9ba3d => 'Retain';

  @override
  String s91c3d72d1e(String p0) {
    return 'fan $p0';
  }

  @override
  String get s40032ddea9 => ', swing';

  @override
  String get s7068e8892e =>
      'Unknown code without raw data. Enable raw data in Tasmota (SetOption58 1) and try again.';

  @override
  String get s6207a45bff => 'IR blaster (heat pump)';

  @override
  String get s859c2e7734 => 'Blaster firmware';

  @override
  String get s3f8d3fb444 =>
      'tasmota_http = Tasmota (tasmota-ir) by IP. tasmota_mqtt = Tasmota via an MQTT broker. esphome = ESPHome climate_ir. http/mqtt = other blaster with your own templates.';

  @override
  String get s38471ae691 => 'Blaster address';

  @override
  String get sda91fafa54 =>
      'IP address of the IR blaster (Tasmota or ESPHome).';

  @override
  String get sf9220a3e4d => 'Brand IR protocol';

  @override
  String get s423f2576c4 =>
      'Tasmota IRhvac vendor, e.g. MITSUBISHI_AC, PANASONIC_AC, DAIKIN. If nothing happens, try another protocol of the same brand.';

  @override
  String get s74ff2fd8a8 => 'Model (optional)';

  @override
  String get sef4c0e5d90 =>
      'IRhvac Model number for some brands. Leave empty if unsure.';

  @override
  String get s8e7962c184 => 'Tasmota topic';

  @override
  String get s5ae4cc50db =>
      'MQTT only: from Tasmota (Configuration → MQTT → Topic).';

  @override
  String get sed30580f59 => 'MQTT broker address';

  @override
  String get s744ce256bb => 'MQTT only: the machine running the broker.';

  @override
  String get se6754df705 => 'MQTT port';

  @override
  String get sbfc8ee6c86 => 'Username';

  @override
  String get s711670d91a => 'MQTT or web user.';

  @override
  String get s3bbd70773d => 'Leave empty if not needed.';

  @override
  String get s443fe6f350 => 'ESPHome climate id';

  @override
  String get s62feae1a9f => 'ESPHome only: the climate object id.';

  @override
  String get se0efd6dfb3 => 'Command URL (other blaster)';

  @override
  String get s5366cbd4df =>
      'http only: URL that receives the full state. Placeholders as listed.';

  @override
  String get sce533db7c1 => 'Payload template (other blaster)';

  @override
  String get s0fa691e7c7 =>
      'http body or mqtt payload. Empty = IRhvac JSON ({{json}}).';

  @override
  String get s8567c5faa6 =>
      'summary = full state as text. room = the blaster\'s temperature sensor. Others = last sent setting.';

  @override
  String get sdd8cd8132c => 'What to change';

  @override
  String get s2e8b846390 =>
      'The whole state is always sent at once. The value comes from the tile or \"Value\".';

  @override
  String get sb517d97868 =>
      'E.g. heat, cool, auto, dry, fan or on/off. Empty = tile value.';

  @override
  String get sda4a1b2eee => 'Learned code';

  @override
  String get s0cfc723aa2 =>
      'Filled when you save a learned remote button. Sent with Tasmota IRsend.';

  @override
  String get s3f26cb7602 => 'ESPHome button';

  @override
  String get sc71964f422 =>
      'ESPHome only: id of the template button for a learned code.';

  @override
  String get s852a166240 => 'Blaster address missing.';

  @override
  String get s75ce01c354 => 'Tasmota needs the web password.';

  @override
  String sf9d84ad23c(String p0) {
    return 'Tasmota does not know $p0. Install the tasmota-ir build.';
  }

  @override
  String sff167aa9a6(String p0) {
    return 'Tasmota rejected the command: $p0';
  }

  @override
  String s385c6a9a2d(String p0) {
    return 'Unknown vendor \"$p0\".';
  }

  @override
  String sb4ea2389cb(String p0) {
    return 'ESPHome climate \"$p0\" not found.';
  }

  @override
  String get s34deda2c72 => 'Command URL missing.';

  @override
  String get s04e4777aea => 'Temperature missing.';

  @override
  String get sfce1a094cb => 'No temperature sensor on the blaster.';

  @override
  String s4536eb33dd(String p0) {
    return 'No temperature received.';
  }

  @override
  String get s9b5bbfa2c6 => 'Room temperature only from Tasmota/ESPHome.';

  @override
  String get s5acc16dafb => 'RF433 needs Tasmota.';

  @override
  String get s8478662ad1 => 'Learned codes need Tasmota.';

  @override
  String s9f8263b5a0(String p0, String p1) {
    return 'ESPHome button \"$p0\" not found.';
  }

  @override
  String s3296e8d7e7(String p0) {
    return 'No code within $p0 s. Point the remote straight at the blaster (under 1 m) and press again.';
  }

  @override
  String get s1e73ba395d => 'RF433 learning needs Tasmota.';

  @override
  String get scc47b4b225 => 'Learning works with Tasmota and ESPHome blasters.';

  @override
  String s96adaaf2b6(String p0, String p1, String p2) {
    return '✓ Tasmota answered (version $p0). Tested: Status 0 at $p1. Nothing was sent to the heat pump.';
  }

  @override
  String sfce5c770f1(String p0) {
    return 'Broker OK but Tasmota \"$p0\" did not answer.';
  }

  @override
  String s2c3b95a054(String p0) {
    return '✓ Tasmota \"$p0\" answered via MQTT. Nothing sent to the heat pump.';
  }

  @override
  String scf9ead3297(String p0, String p1, String p2, String p3) {
    return '✓ ESPHome climate \"$p0\" found. Nothing was sent.';
  }

  @override
  String get s8ad50358b9 =>
      'No test for other blasters: IR is one-way. Press the power tile and watch the heat pump.';

  @override
  String s3b476099a2(String p0) {
    return 'Device answered HTTP $p0. Is web_server enabled in ESPHome?';
  }

  @override
  String sd44aec7380(String p0) {
    return 'No answer from $p0.';
  }

  @override
  String s120026628c(String p0) {
    return 'Could not reach $p0.';
  }

  @override
  String get s43c9b88580 => 'Auto';

  @override
  String get s018d2e08f4 => 'Fan';

  @override
  String get s36fb6ba26f => 'Modbus TCP';

  @override
  String get sa70cc38354 => 'Host';

  @override
  String get sdc5301b750 => 'Unit id';

  @override
  String get s15e327bf8e => 'Timeout (ms)';

  @override
  String get s943b8b6bf3 => 'Register table';

  @override
  String get sf51ad986eb => 'Address (0-based)';

  @override
  String get s601f118ac0 => 'Data type';

  @override
  String get sddd62d21b0 => 'Swap words (CDAB)';

  @override
  String get see24ec5d84 => 'Scale';

  @override
  String get s0a239b832b => 'Offset';

  @override
  String get s5f374d3643 => 'Unit id (empty = connection)';

  @override
  String get sef11962984 => 'Write to';

  @override
  String get s779b59ba4b => 'Value ({{value}} = slider/toggle)';

  @override
  String get sefaea1b818 => 'ntfy (message channel / commands)';

  @override
  String get s6a4516e0fe => 'Command topic (name or full URL)';

  @override
  String get se003ecc10b =>
      'Topic the commands are sent to. You can paste the full URL, e.g. https://ntfy.sh/my-topic – the same one your iPhone Shortcut uses. The topic name works like a password: keep it long and random.';

  @override
  String get s800cd08229 => 'Reply topic (optional)';

  @override
  String get s2e3a66d384 =>
      'If the home device replies on another topic, type it here. Leave empty if the reply comes on the same topic – our own command is then ignored and the next message is shown as the reply.';

  @override
  String get s5bc736c04a => 'Access token (optional)';

  @override
  String get s77feae14f5 =>
      'Only needed for a protected topic (ntfy account → Access tokens). Leave empty for a public topic.';

  @override
  String get seca0d75969 =>
      'Default is the public ntfy.sh. Change only for your own ntfy server. A full URL above overrides this.';

  @override
  String get sddbea594a4 =>
      'latest = the newest message, log = several recent messages (newest first).';

  @override
  String get s2bd0e69d44 => 'Topic (optional)';

  @override
  String get s4eb1e8ac15 =>
      'Topic to read. Empty = the connection\'s reply topic (or the command topic).';

  @override
  String get s09fa5c0332 => 'Number of messages (log)';

  @override
  String get s17fda9fb06 => 'How many recent messages the log shows.';

  @override
  String get s78f2f0d783 => 'How far back';

  @override
  String get s79bdbfd820 =>
      'E.g. 30m, 12h or 2d. The public ntfy.sh keeps messages for about 12 hours.';

  @override
  String get sfe357edcec => 'Command (text to send)';

  @override
  String get s48e102023d =>
      'The text to send, e.g. \"update\". With a PIN it is appended after a space: \"update 1234\".';

  @override
  String get saf2ebedf61 => 'Ask for a PIN on press';

  @override
  String get sfcb5608064 =>
      'Asks for a PIN (hidden) on every press and appends it to the command. The PIN is not stored unless you choose \"Remember on this device\".';

  @override
  String get sfee393b70e => 'Wait for the reply';

  @override
  String get sfff5bc52e5 =>
      'Listens for the home device\'s reply and shows it in this tile (and as a notification when the app is in the background).';

  @override
  String get sbdcbe301b9 => 'Wait for reply (s)';

  @override
  String get s121542d6d7 =>
      'How long to wait before saying that no reply came.';

  @override
  String get sa53638cfea => 'Reply stays on the tile (s)';

  @override
  String get se6d21484a8 =>
      'How long the reply stays on the tile. 0 = until the next press.';

  @override
  String get s74d68a98d6 => 'Message title (optional)';

  @override
  String get sc2492ac3ab => 'ntfy message title. Usually empty.';

  @override
  String s54ea45f27f(String p0, String p1) {
    return 'ntfy: topic \"$p0\" is protected (HTTP $p1). Add an access token (tk_…) to the connection.';
  }

  @override
  String get s72c37e530d =>
      'ntfy: too many messages (HTTP 429). Wait a moment and try again.';

  @override
  String get s0870daf796 => 'ntfy: command topic missing';

  @override
  String get s28dc7ea012 => 'ntfy: connection closed before the reply';

  @override
  String sa4313864fe(String p0, String p1) {
    return 'The command was sent, but no reply came within $p0 s. Check that the home device is on and listens to \"$p1\".';
  }

  @override
  String get s85a1947a44 => '(no messages)';

  @override
  String get s7069b18b7d => 'ntfy: command text missing';

  @override
  String s43de3fd299(String p0) {
    return ' Reply topic: $p0.';
  }

  @override
  String s9ed9eb7f92(String p0, String p1, String p2, String p3) {
    return '✓ ntfy server $p0 answered and topic \"$p1\" is readable ($p2 messages in the last hour).$p3 No command was sent – tap the tile to try.';
  }

  @override
  String get sf0ef0140c3 => 'Home Assistant';

  @override
  String get s1f90ee6992 => 'Long-lived access token';

  @override
  String get sccb0cca8e3 => 'Live updates (websocket)';

  @override
  String get s8f8e1cfad3 => 'Entity id';

  @override
  String get s382111aebc => 'Attribute (empty = state)';

  @override
  String get sf500d0ad67 => 'Service';

  @override
  String get s7286715019 => 'Extra data JSON ({{value}} = value)';

  @override
  String get s1b5b0421c0 => 'Payload is hex';

  @override
  String get s44ab1d33df => 'Wait for response';

  @override
  String get s341bf61e36 => 'Response as hex';

  @override
  String get se7cff2d61e => 'TCP (raw)';

  @override
  String get s1dfeacd9f6 => 'UDP';

  @override
  String get s804e935440 => 'ESP32 camera';

  @override
  String get s478ddb6e1a => 'Ventilation unit (Modbus)';

  @override
  String get s4b4fd14aaf => 'Yard';

  @override
  String get s8ac16d45bc => '';

  @override
  String get sbde42d83a3 => 'Living room lights';

  @override
  String get sb7c78c63b3 => 'Supply air';

  @override
  String get sbb2adef009 => 'Fan speed';

  @override
  String get see46441329 => '0=Off;1=Away;2=Home;3=Boost;4=Max';

  @override
  String get sb25aad3bc2 => 'Leaving home';

  @override
  String get s7e461faf91 =>
      'Find it in your router\'s device list or the device app. You can also tap \"Search network\".';

  @override
  String get saf4b222a68 => 'Device IP address';

  @override
  String get s1bbea216af => 'ESP32-CAM camera';

  @override
  String get saaaeccd0cc => 'Low-cost Wi-Fi camera. Shows live video.';

  @override
  String get saaea39b2de => 'Camera IP address';

  @override
  String get s6ef2a3f197 =>
      'Shown in the serial monitor at boot or in the router device list.';

  @override
  String get sae199413a2 => 'E.g. Yard, Hallway.';

  @override
  String get s2dd165b39f => 'Image type';

  @override
  String get sb66b153f36 =>
      'mjpeg = live video (recommended). snapshot = still image every few seconds.';

  @override
  String get sf81257929d => 'Shelly relay / plug';

  @override
  String get s2b8ab6defc =>
      'Switch a light or appliance on/off and show power.';

  @override
  String get s7fcea114f0 => 'What does it control?';

  @override
  String get s864ba0233b =>
      'Newer (Plus, Pro, Gen3) = Plus / Pro / Gen2+. Old Shelly 1, 2.5, Plug S = Gen1.';

  @override
  String get s92f97cd95e => 'Show power (W)';

  @override
  String get s54c71d86aa => 'Only for models with metering (e.g. Plus 1PM).';

  @override
  String get s49671fc56f => 'Channel';

  @override
  String get s06f8a27d8a => 'For multi-channel devices: 0 = first.';

  @override
  String get s259e46c59a => 'Only if you set a password.';

  @override
  String get sc130e073ba => 'Relay or plug running Tasmota firmware.';

  @override
  String get s16be1831d6 => 'Only for devices with energy metering.';

  @override
  String get s8890d26ef2 => 'Relay number';

  @override
  String get s7e6d21d466 => 'For multi-relay devices 1, 2, 3...';

  @override
  String get s5f1e4a036e => 'Web password';

  @override
  String get s397e83233d => 'Only if a web password is set (user admin).';

  @override
  String get sa0efcdf688 =>
      'Your own ESP32/ESP8266 with ESPHome (web_server enabled).';

  @override
  String get s631420589f => 'Device name';

  @override
  String get s1db899640b => 'Switch id (optional)';

  @override
  String get sb2e87033fc =>
      'The switch name from YAML in lower case with underscores.';

  @override
  String get s978ae8f1d6 => 'Sensor id (optional)';

  @override
  String get s4ba12c5866 =>
      'Sensor name in the same way (see the device web page).';

  @override
  String get s945273ef29 => 'Sensor unit';

  @override
  String get s5ca2e25792 => 'Only if web_server auth is set.';

  @override
  String get sb847f22473 => 'Web username';

  @override
  String get s76f6067b0f =>
      'Lights, alarm, sensors – pick from a list which ones become tiles.';

  @override
  String get s9f70681d3f => 'Home Assistant address';

  @override
  String get s123502628e => 'The address you open Home Assistant with.';

  @override
  String get s92e3c4cd40 => 'Long-lived token';

  @override
  String get s4e3f2052b2 =>
      'Home Assistant → your profile → Security → Long-lived access tokens → Create token. Paste it here.';

  @override
  String get s54e063bd9c => 'Heat pump (Home Assistant)';

  @override
  String get s2afe650320 =>
      'Air heat pump shown in Home Assistant as a climate entity.';

  @override
  String get s48fdd98530 => 'If already added, the same connection is reused.';

  @override
  String get sfe5ad3202f => 'Not needed if HA is already added.';

  @override
  String get sce069d8d1a => 'Heat pump entity';

  @override
  String get s05e2aaa15c => 'Starts with climate.';

  @override
  String get se699281c85 => 'Heat pump (MQTT)';

  @override
  String get s8643040b95 =>
      'E.g. mitsubishi2mqtt or similar ESP controller. Topics are examples – verify.';

  @override
  String get s2a1148ee77 => 'MQTT broker IP';

  @override
  String get s53e472c976 => 'Machine running Mosquitto (often the HA box).';

  @override
  String get s29aff3d2a0 => 'MQTT username';

  @override
  String get s37e57de4b9 => 'Leave empty if not required.';

  @override
  String get sffe00ea1b3 => 'MQTT password';

  @override
  String get s407d4a5e56 => 'Base topic';

  @override
  String get sc1af622c0a =>
      'From the controller settings. State: <base>/state, commands: <base>/set.';

  @override
  String get s9783a8fd53 => 'room';

  @override
  String get sbc996a7d25 => 'setpoint';

  @override
  String get sa69c0e1ca3 => 'Air heat pump (IR)';

  @override
  String get s025e7bf04d =>
      'Control any remote-controlled heat pump with an IR blaster (Tasmota or ESPHome). IR is one-way: Molaplan shows what it last sent.';

  @override
  String get sb5d4127728 => 'IR blaster';

  @override
  String get sc899cf95db =>
      'Most ready-made IR blasters run Tasmota (use the tasmota-ir build). ESPHome = your ESPHome device with climate_ir.';

  @override
  String get sc096a735fd =>
      'IP of the IR blaster. For MQTT, the broker address.';

  @override
  String get safc7f1325c => 'Heat pump brand';

  @override
  String get s7675ec1754 =>
      'Pick the brand of the unit or remote. If it does not react, try \"Other\" with an alternative protocol.';

  @override
  String get s9702830f91 => 'Protocol (only \"Other\")';

  @override
  String get s6df0837908 =>
      'Tasmota IRhvac vendor name. Only needed for \"Other\" or to try another.';

  @override
  String get saa49bfdb90 => 'Shown in tile titles.';

  @override
  String get sf1971ac29b => 'Tasmota topic (MQTT only)';

  @override
  String get s65529d5877 =>
      'Tasmota → Configuration → MQTT → Topic. Other MQTT blaster: command topic.';

  @override
  String get s321c1677e2 => 'ESPHome climate id (ESPHome only)';

  @override
  String get s4c07dec7b5 =>
      'The climate_ir object id, shown on the device web page.';

  @override
  String get s2229e548f3 => 'MQTT or web user.';

  @override
  String get s06cff48000 => 'Command URL (other HTTP only)';

  @override
  String get s5b41e244d6 =>
      'Placeholders: {{power}} {{mode}} {{temp}} {{fan}} {{swing}} {{vendor}} {{json}}.';

  @override
  String get s9a60c2026e => 'Mode buttons';

  @override
  String get sd119ce3382 => 'Buttons for heat, cool, auto, dry and fan.';

  @override
  String get s9b8dd7076a => 'Fan speed';

  @override
  String get s9597aa1ae9 => 'Slider 0–5 (0 = auto).';

  @override
  String get secae50c5dd => 'Swing';

  @override
  String get s8bcb8433f9 => 'Louver swing on/off.';

  @override
  String get s78a5e5fa61 => 'Room temperature from the blaster sensor';

  @override
  String get s2dd6395602 => 'Only if the blaster has a temperature sensor.';

  @override
  String get s4ff78f06ab => 'Air heat pump (service port / ESPHome)';

  @override
  String get s6cc7b6b499 =>
      'ESPHome controller on the indoor unit service port (Mitsubishi CN105, Daikin S21/X50A, Panasonic CN-CNT, Toshiba). Two-way: real state and room temperature.';

  @override
  String get s647e86e5e5 => 'Climate id';

  @override
  String get sbeb6af1e1c =>
      'The climate entity of the ESPHome device. \"Find heat pumps\" in the guide finds it for you.';

  @override
  String get sbf36d139cb => 'Only if web_server has auth.';

  @override
  String get s54d4fdbba4 => 'Only if web_server has auth.';

  @override
  String get s84cd6a5180 => 'RF433 remote (Athom IR & RF)';

  @override
  String get s4105198757 =>
      'Control RF433 radio-remote devices (sockets, awnings, garage doors) with the Athom \"Tasmota IR & RF433 Controller\". You teach the buttons right after adding.';

  @override
  String get sbc2bf08889 => 'IP of the Athom controller.';

  @override
  String get sc34430eec0 => 'E.g. what you control.';

  @override
  String get s12447972e0 => 'Only if a Tasmota web password is set.';

  @override
  String get s6385f1487e => 'Electricity price (spot)';

  @override
  String get se807a72c0a =>
      'Today\'s and tomorrow\'s spot price as a chart. Price control: long-press a device tile → Price control.';

  @override
  String get sef8d24c969 => 'Country / price area';

  @override
  String get sef4f509f9f =>
      'Pick your country; in Sweden and Norway your area.';

  @override
  String get sf3a8631d14 => 'From your bill incl. VAT. 0 = energy only.';

  @override
  String get sf3be8aac1c => 'Your contract margin without VAT.';

  @override
  String s49dfca65a3(String p0) {
    return 'Electricity price $p0';
  }

  @override
  String get s9af9526395 => 'Ventilation unit (Modbus TCP)';

  @override
  String get s29dc0baf55 =>
      'Temperatures and fan speed. Register presets are examples – verify with your manual.';

  @override
  String get sb75966bb58 => 'Unit or gateway IP';

  @override
  String get s751331a84a =>
      'If the unit has only RS485, you need an RS485 → Modbus TCP gateway. Enter its IP.';

  @override
  String get s658cdb6ff8 => 'Brand';

  @override
  String get s785c0c264c =>
      'Pick a brand to prefill registers as an example. \"—\" = empty.';

  @override
  String get s7e9c785c20 => 'Often 1.';

  @override
  String get s0591744c19 => 'Almost always 502.';

  @override
  String get s5ccb7405cf => 'Ventilation';

  @override
  String get se7dfa3594e => 'MQTT device';

  @override
  String get s12ab103795 =>
      'Any device that speaks MQTT (Zigbee2MQTT, your own ESP, ...).';

  @override
  String get sffcfefd91c => 'Machine running the MQTT broker.';

  @override
  String get s6ac05d979c => 'What is it?';

  @override
  String get s460d48d0cc => 'switch = on/off, sensor = shows a value.';

  @override
  String get s850c7e1194 => 'State topic';

  @override
  String get s49b7311a1e => 'Topic where the device reports its state.';

  @override
  String get s579969e7e4 => 'Command topic (switch)';

  @override
  String get s137db4076a => 'Topic for the on/off command.';

  @override
  String get s4c95226869 => 'On message';

  @override
  String get s70f2ea8532 => 'Off message';

  @override
  String get sdc234849ac => 'JSON field';

  @override
  String get sd3f60d4a71 => 'If the message is JSON, the field name.';

  @override
  String get s6cee917658 => 'Unit (sensor)';

  @override
  String get s3cd541d271 => 'Other Wi-Fi device (HTTP)';

  @override
  String get s69885630aa =>
      'A device with a web API. Shows one value; add more tiles later.';

  @override
  String get s200320e245 => 'Status path';

  @override
  String get sc5872d2e30 =>
      'Where the device reports its state. Empty = no tile now.';

  @override
  String get s5564de12b2 => 'Field to show';

  @override
  String get s377942beb7 => 'Field name in the reply.';

  @override
  String get sbaf1a279c2 => 'Command and reply (ntfy)';

  @override
  String get se0fb2c7eea =>
      'Send a command as an ntfy message (e.g. \"update\" + PIN) and see the home device\'s reply in the same tile. Same channel as an iPhone Shortcut.';

  @override
  String get s8231329360 => 'Command topic URL';

  @override
  String get sd82d127f05 =>
      'Paste the same URL your Shortcut posts commands to (e.g. https://ntfy.sh/kv-cmd-…). The topic name alone also works.';

  @override
  String get s1b3bbae234 =>
      'Only if the home device replies on another topic. Empty = same topic, our own command is ignored.';

  @override
  String get s1b08aa4646 =>
      'Text shown on the tile, e.g. \"Update\" or \"Status\".';

  @override
  String get s5bed8bff00 => 'Command';

  @override
  String get se2a81ae67d =>
      'The text to send. The PIN is appended after a space, e.g. \"update 1234\".';

  @override
  String get s1477964f04 => 'Ask for the PIN on every press';

  @override
  String get s62672283f6 =>
      'The PIN is asked hidden and is not stored unless you choose \"Remember on this device\".';

  @override
  String get sb5e914eaf7 =>
      'Only for a protected topic. Leave empty for a public topic.';

  @override
  String get s1a98a7e424 => 'Also add a message log tile';

  @override
  String get s5ab6348524 =>
      'Shows the latest messages of the topic in its own tile.';

  @override
  String get s57e684ac9e => 'Messages';

  @override
  String s3378eb2d0b(String p0) {
    return '$p0 – temperature';
  }

  @override
  String get saa437260b8 => 'Sent state (IR is one-way)';

  @override
  String get sfffb54daf4 => 'State';

  @override
  String get seab2c72485 => 'Fan (0 = auto)';

  @override
  String s3a38b97f7b(String p0) {
    return '$p0 – room';
  }
}
