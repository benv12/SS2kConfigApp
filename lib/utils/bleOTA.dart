/*
 * Copyright (C) 2020  Anthony Doud
 * All rights reserved
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */

// ignore_for_file: annotate_overrides, avoid_print, prefer_const_constructors

// Import necessary libraries
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

// Abstract class defining the structure of an OTA package
abstract class OtaPackage {
  // Method to update firmware
  Future<void> updateFirmware(BluetoothDevice device, int firmwareType, BluetoothService service,
      BluetoothCharacteristic dataUUID, BluetoothCharacteristic controlUUID,
      {String? binFilePath, String? url});

  // Property to track firmware update status
  bool firmwareupdate = false;

  // Stream to provide progress percentage
  Stream<int> get percentageStream;
}

// Class responsible for handling BLE repository operations
class BleRepository {
  // Write data to a Bluetooth characteristic
  Future<void> writeDataCharacteristic(BluetoothCharacteristic characteristic, Uint8List data) async {
    await characteristic.write(data);
  }

  // Read data from a Bluetooth characteristic
  Future<List<int>> readCharacteristic(BluetoothCharacteristic characteristic) async {
    return await characteristic.read();
  }

  // Request a specific MTU size from a Bluetooth device
  Future<void> requestMtu(BluetoothDevice device, int mtuSize) async {
    await device.requestMtu(mtuSize);
  }
}

// Implementation of OTA package for ESP32
class Esp32OtaPackage implements OtaPackage {
  final BluetoothCharacteristic dataCharacteristic;
  final BluetoothCharacteristic controlCharacteristic;
  bool firmwareupdate = false;
  final StreamController<int> _percentageController = StreamController<int>.broadcast();
  @override
  Stream<int> get percentageStream => _percentageController.stream;

  Esp32OtaPackage(this.dataCharacteristic, this.controlCharacteristic);

  @override
  Future<void> updateFirmware(BluetoothDevice device, int firmwareType, BluetoothService service,
      BluetoothCharacteristic dataUUID, BluetoothCharacteristic controlUUID,
      {String? binFilePath, String? url}) async {
    final bleRepo = BleRepository();

    // Get MTU size from the device
    const int mtuOffsetForChunkSize = 3;
    int mtuSize = await device.mtu.first;
    int chunkSize = mtuSize - mtuOffsetForChunkSize;

    print("MTU size for current device $mtuSize");

    // Prepare a byte list to write MTU size to controlCharacteristic
    Uint8List byteList = Uint8List(2);
    byteList[0] = chunkSize & 0xFF;
    byteList[1] = (chunkSize >> 8) & 0xFF;

    List<Uint8List> binaryChunks;

    // Get firmware chunks based on the type and provided file path
    if (binFilePath != null && binFilePath.isNotEmpty) {
      if (firmwareType == 1) {
        // Built-in firmware
        binaryChunks = await _readBinaryFile(binFilePath, chunkSize);
      } else if (firmwareType == 2) {
        // File picker
        binaryChunks = await _getFirmwareFromPicker(chunkSize);
      } else {
        // URL or Beta firmware - read from the downloaded file
        binaryChunks = await _readLocalFile(binFilePath, chunkSize);
      }
    } else {
      throw Exception('No firmware file path provided');
    }

    if (binaryChunks.isEmpty) {
      throw Exception('No firmware data available');
    }

    // Write x01 to the controlCharacteristic and check if it returns value of 0x02
    await bleRepo.writeDataCharacteristic(controlCharacteristic, Uint8List.fromList([1]));

    // Read value from controlCharacteristic
    List<int> value = await bleRepo.readCharacteristic(controlCharacteristic).timeout(Duration(seconds: 10));
    print('value returned is this ------- ${value[0]}');

    int packageNumber = 0;
    for (Uint8List chunk in binaryChunks) {
      await bleRepo.writeDataCharacteristic(dataCharacteristic, chunk).timeout(Duration(seconds: 10), onTimeout: () {
        // If a timeout occurs, throw a custom exception to be caught by the catch block
         firmwareupdate = false;
        _percentageController.close();
        throw TimeoutException('Failed to write data chunk #$packageNumber');
      });
      packageNumber++;

      double progress = (packageNumber / binaryChunks.length) * 100;
      int roundedProgress = progress.round(); // Rounded off progress value
      print('Writing package number $packageNumber of ${binaryChunks.length} to ESP32');
      print('Progress: $roundedProgress%');
      _percentageController.add(roundedProgress);
    }

    // Check if controlCharacteristic reads 0x05, indicating OTA update finished
    value = await bleRepo.readCharacteristic(controlCharacteristic).timeout(Duration(seconds: 600));
    print('value returned is this ------- ${value[0]}');

    if (value[0] == 5) {
      print('BLE OTA update finished');
      firmwareupdate = true; // Firmware update was successful
    } else {
      print('BLE OTA update failed');
      firmwareupdate = false; // Firmware update failed
    }
    _percentageController.close();
  }

  // Convert Uint8List to List<int>
  List<int> uint8ListToIntList(Uint8List uint8List) {
    return uint8List.toList();
  }

  // Read binary file from assets and split it into chunks
  Future<List<Uint8List>> _readBinaryFile(String filePath, int chunkSize) async {
    final ByteData data = await rootBundle.load(filePath);
    final List<int> bytes = data.buffer.asUint8List();
    return _splitIntoChunks(bytes, chunkSize);
  }

  // Read binary file from local filesystem and split it into chunks
  Future<List<Uint8List>> _readLocalFile(String filePath, int chunkSize) async {
    final bytes = await File(filePath).readAsBytes();
    return _splitIntoChunks(bytes, chunkSize);
  }

  // Helper method to split bytes into chunks
  List<Uint8List> _splitIntoChunks(List<int> bytes, int chunkSize) {
    List<Uint8List> chunks = [];
    for (int i = 0; i < bytes.length; i += chunkSize) {
      int end = i + chunkSize;
      if (end > bytes.length) {
        end = bytes.length;
      }
      chunks.add(Uint8List.fromList(bytes.sublist(i, end)));
    }
    return chunks;
  }

  // Get firmware based on firmwareType
  Future<List<Uint8List>> getFirmware(int firmwareType, int chunkSize, {String? binFilePath}) {
    if (firmwareType == 2) {
      print("in package MTU size is ${chunkSize}");
      return _getFirmwareFromPicker(chunkSize);
    } else if (firmwareType == 1 && binFilePath != null && binFilePath.isNotEmpty) {
      return _readBinaryFile(binFilePath, chunkSize);
    } else if (binFilePath != null && binFilePath.isNotEmpty) {
      return _readLocalFile(binFilePath, chunkSize);
    } else {
      return Future.value([]);
    }
  }

  // Get firmware chunks from file picker
  Future<List<Uint8List>> _getFirmwareFromPicker(int chunkSize) async {
    print("MTU size in fie picker is ${chunkSize}");
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bin'],
    );

    if (result == null || result.files.isEmpty) {
      return []; // Return an empty list when no file is picked
    }

    final file = result.files.first;

    try {
      final firmwareData = await _openFileAndGetFirmwareData(file, chunkSize);

      if (firmwareData.isEmpty) {
        throw 'Empty firmware data. Please select a valid firmware file.';
      }

      return firmwareData;
    } catch (e) {
      throw 'Error getting firmware data: $e';
    }
  }

  // Open file, read bytes, and split into chunks
  Future<List<Uint8List>> _openFileAndGetFirmwareData(PlatformFile file, int chunkSize) async {
    final bytes = await File(file.path!).readAsBytes();
    return _splitIntoChunks(bytes, chunkSize);
  }

  // Fetch firmware chunks from a URL
  Future<List<Uint8List>> _getFirmwareFromUrl(String url, int chunkSize) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      // Check if the HTTP request was successful (status code 200)
      if (response.statusCode == 200) {
        final List<int> bytes = response.bodyBytes;
        return _splitIntoChunks(bytes, chunkSize);
      } else {
        // Handle HTTP error (e.g., status code is not 200)
        throw 'HTTP Error: ${response.statusCode} - ${response.reasonPhrase}';
      }
    } catch (e) {
      // Handle other errors (e.g., timeout, network connectivity issues)
      throw 'Error fetching firmware from URL: $e';
    }
  }
}
