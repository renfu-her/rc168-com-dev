import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:rc168/main.dart';

class AddressAddPage extends StatefulWidget {
  @override
  _AddressAddPageState createState() => _AddressAddPageState();
}

class _AddressAddPageState extends State<AddressAddPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _customFieldController = TextEditingController();
  final TextEditingController _zoneIdController = TextEditingController();

  String _countryId = '206'; // 应该从一个下拉菜单中选择
  String _zoneId = '3139'; // 应该从一个下拉菜单中选择
  bool _isDefault = false; // 根据用户的选择设置
  List<Country> _countries = [];
  List<Zone> _zones = [];
  String _selectedCountryId = '206'; // 預設值
  String _selectedZoneId = '3139'; // 預設值

  bool _validateAndSaveForm() {
    final form = _formKey.currentState;
    if (form != null && form.validate()) {
      form.save(); // Save the form if it's valid
      return true;
    }
    return false;
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> addAddress() async {
    // Build the FormData
    if (_formKey.currentState!.validate()) {
      final formData = FormData.fromMap({
        'firstname': _firstNameController.text,
        'lastname': _lastNameController.text,
        'company': _companyController.text,
        'address_1': _address1Controller.text,
        'address_2': _address2Controller.text,
        'postcode': _postcodeController.text,
        'country_id': _selectedCountryId.toString(),
        'zone_id': _selectedZoneId.toString(),
        'city': _cityController.text,
        'custom_field': '{1: 711}',
        'default': _isDefault
            ? '1'
            : '0', // Assuming the API expects '1' for true and '0' for false
      });

      // // Send the POST request
      try {
        final response = await dio.post(
          '${app_url}/index.php?route=extension/module/api/gws_customer_address/add&customer_id=${customerId}&api_key=${api_key}',
          data: formData,
        );
        print(response.data);
        if (response.statusCode == 200) {
          // _showDialog('更新', '已經更新');
          Navigator.pop(context);
          Navigator.pop(context);
        } else {
          // Handle the error
          print('Failed to add address');
        }
      } catch (e) {
        // Handle any exceptions
        print('Error occurred: $e');
      }
    }
  }

  @override
  void dispose() {
    // Dispose controllers when the widget is removed
    _firstNameController.dispose();
    _lastNameController.dispose();
    _companyController.dispose();
    _postcodeController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _customFieldController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _onCountrySelected("206");
  }

  Future<void> _loadCountries() async {
    try {
      final response = await dio.get(
          '${app_url}/index.php?route=extension/module/api/gws_country&api_key=${api_key}');
      if (response.statusCode == 200) {
        setState(() {
          _countries = List<Country>.from(response.data['country']
              .map((country) => Country.fromJson(country)));
        });
      }
    } catch (e) {
      // 錯誤處理
    }
  }

  Future<void> _loadZones(String countryId) async {
    try {
      final response = await dio.get(
          '${app_url}/index.php?route=extension/module/api/gws_zone&country_id=$countryId&api_key=${api_key}');
      if (response.statusCode == 200) {
        setState(() {
          _zones = List<Zone>.from(
              response.data['zones'].map((zone) => Zone.fromJson(zone)));

          if (_zones.isNotEmpty) {
            // 選擇列表中的第一個地區作為預設選擇
            _selectedZoneId = _zones.first.id;
          }
        });
      }
    } catch (e) {
      // 錯誤處理
    }
  }

  // 更新選定國家並加載對應的地區
  void _onCountrySelected(String value) {
    setState(() {
      _selectedCountryId = value;
      _selectedZoneId = '0'; // 將 _selectedZoneId 設為 null
      _zones = []; // 清空地區列表
    });
    _loadZones(value);
  }

  @override
  Widget build(BuildContext context) {
    // Build your form widget here using TextFormFields and a submit button
    return Scaffold(
      appBar: AppBar(
        title: Text('增加新地址'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: '名字 *',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入名字';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: '姓式 *',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入姓氏';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _companyController,
                decoration: InputDecoration(
                  labelText: '公司/服務單位',
                ),
              ),
              TextFormField(
                controller: _address1Controller,
                decoration: InputDecoration(
                  labelText: '地址1 *',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入地址1';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _address2Controller,
                decoration: InputDecoration(
                  labelText: '地址2',
                ),
              ),
              TextFormField(
                controller: _postcodeController,
                decoration: InputDecoration(
                  labelText: '郵遞區號 *',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入郵遞區號';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: '區/鄉/鎮 *',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入區/鄉/鎮';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedCountryId,
                items: _countries.map((Country country) {
                  return DropdownMenuItem<String>(
                    value: country.id,
                    child: Text(country.name),
                  );
                }).toList(),
                onChanged: (value) => _onCountrySelected(value!),
              ),
              DropdownButtonFormField<String>(
                value: _selectedZoneId,
                items: _zones.map((Zone zone) {
                  return DropdownMenuItem<String>(
                    value: zone.id,
                    child: Text(zone.name),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedZoneId = value!),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        color: Colors.white,
        width: double.infinity, // 容器宽度占满整个屏幕宽度
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: ElevatedButton(
            onPressed: () {
              if (_validateAndSaveForm()) {
                addAddress();
              } else {
                _showDialog('錯誤', '請填寫必填欄位。');
              }
            },
            child: Text(
              '增加新地址',
              style: TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, // 按钮背景颜色为蓝色
              foregroundColor: Colors.white, // 文本颜色为白色
              minimumSize: Size(double.infinity, 36), // 按钮最小尺寸，宽度占满
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6), // 圆角矩形按钮
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Country {
  String id;
  String name;

  Country({required this.id, required this.name});

  // 從 JSON 數據中解析 Country 對象
  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['country_id'].toString(),
      name: json['name'],
    );
  }
}

class Zone {
  String id;
  String name;

  Zone({required this.id, required this.name});

  // 從 JSON 數據中解析 Zone 對象
  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      id: json['zone_id'].toString(),
      name: json['name'],
    );
  }
}
