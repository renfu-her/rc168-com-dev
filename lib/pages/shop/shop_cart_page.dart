import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:rc168/main.dart';
import 'package:rc168/pages/shop/shop_payment_page.dart';
import 'package:rc168/pages/member/address/address_cart_page.dart';
import 'package:text_responsive/text_responsive.dart';
import 'package:rc168/responsive_text.dart';
import 'package:rc168/pages/shop/shop_payment_bankTransfer_page.dart';

class ShopCartPage extends StatefulWidget {
  final String? addressId;
  const ShopCartPage({super.key, this.addressId});

  @override
  _ShopCartPageState createState() => _ShopCartPageState();
}

class _ShopCartPageState extends State<ShopCartPage> {
  List<Product> products = [];
  bool isLoading = true;
  double totalAmount = 0.0;
  int? _selectedShippingMethodCode;
  String? _selectedPaymentMethod;
  double _selectedShippingCost = 0.0;
  double _tempTotalAmount = 0.0;
  List<DropdownMenuItem<String>> _dropdownItems = [];

  @override
  void initState() {
    super.initState();
    _fetchPaymentMethods();
    fetchCartItems();
    getCustomerDataAndFetchAddress(widget.addressId);
    if (widget.addressId != null) {
      String? address = widget.addressId;
      setState(() {
        fetchCustomerAddress(defaultAddressId: address!);
      });
    } else {
      getCustomerDataAndFetchAddress(widget.addressId);
    }
    // fetchShippingMethods();
  }

  Future<void> getCustomerDataAndFetchAddress(String? defaultAddressId) async {
    if (defaultAddressId != null) {
      await fetchCustomerAddress(defaultAddressId: defaultAddressId);
    } else {
      try {
        // 從 gws_customer 獲取用戶資料
        var customerResponse = await dio.get('${appUri}/gws_customer',
            queryParameters: {'customer_id': customerId, 'api_key': apiKey});
        var customer = customerResponse.data;

        // 提取 default_address_id
        String defaultAddressId =
            customer['customer'][0]['default_address_id'] ?? '';
        customerData = customer;
        // 使用提取的 default_address_id 調用 fetchCustomerAddress
        await fetchCustomerAddress(defaultAddressId: defaultAddressId);
      } catch (e) {
        print(e);
        // 處理異常或顯示錯誤信息
      }
    }
  }

  Future<void> fetchCartItems() async {
    final customerCartUrl =
        '${appUri}/gws_appcustomer_cart&customer_id=${customerId}&api_key=${apiKey}';
    final productDetailBaseUrl = '${appUri}/gws_product&product_id=';

    setState(() {
      products.clear();
      totalAmount = 0.0;
      isLoading = true;
    });
    try {
      // Fetch the cart items
      var cartResponse = await dio.get(customerCartUrl);
      var cartData = cartResponse.data;

      if (cartData['message'][0]['msg_status'] == true) {
        // Fetch details for each product in the cart
        for (var cartItem in cartData['customer_cart']) {
          var productResponse = await dio.get(
              '$productDetailBaseUrl${cartItem['product_id']}&api_key=${apiKey}');
          var productData = productResponse.data;

          if (productData['message'][0]['msg_status'] == true) {
            // Parse cart item option
            var cartItemOption = jsonDecode(cartItem['option']);
            var productOptions = productData['product'][0]['options'];

            var selectedOptions = [];
            productOptions.forEach((option) {
              var productOptionId = option['product_option_id'].toString();
              if (cartItemOption.containsKey(productOptionId)) {
                var productOptionValueId = cartItemOption[productOptionId];
                var optionValue = option['product_option_value'].firstWhere(
                    (value) =>
                        value['product_option_value_id'].toString() ==
                        productOptionValueId,
                    orElse: () => null);

                if (optionValue != null) {
                  selectedOptions.add({
                    'product_option_id': option['product_option_id'].toString(),
                    'product_option_value_id':
                        optionValue['product_option_value_id'].toString(),
                    'type': option['type'],
                    'value': optionValue['name'],
                    'name': option['name'],
                  });
                }
              }
            });

            // Create combined data map
            var combinedData =
                Map<String, dynamic>.from(productData['product'][0])
                  ..addAll({
                    'quantity': cartItem['quantity'],
                    'cart_id': cartItem['cart_id'],
                    'options': selectedOptions,
                    'totals': cartData['totals']
                  });

            var product = Product.fromJson(combinedData);
            print(cartData['totals']);

            setState(() {
              products.add(product);
              product.special != false
                  ? totalAmount += product.special * product.quantity
                  : totalAmount += product.price * product.quantity;

              product.special != false
                  ? _tempTotalAmount += product.special * product.quantity
                  : _tempTotalAmount += product.price * product.quantity;
            });
          }
        }
      }
    } on DioException catch (e) {
      // Handle errors
      print(e);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchCustomerAddress({String defaultAddressId = ''}) async {
    try {
      // 如果有提供 defaultAddressId，則直接使用
      String addressId = defaultAddressId;
      // print{'addressId 1: ${addressId}');

      if (addressId.isEmpty) {
        // 如果沒有提供 defaultAddressId，則從 gws_customer 獲取
        var customerResponse = await dio.get('${appUri}/gws_customer',
            queryParameters: {'customer_id': customerId, 'api_key': apiKey});
        var customerData = customerResponse.data;
        addressId = customerData['default_address_id'] ?? '';
      }

      Response addressResponse;
      if (addressId.isNotEmpty) {
        // print('fetchCustomerAddress: ${addressId}');
        // Fetch specific address
        addressResponse = await dio.get('$appUri/gws_customer_address',
            queryParameters: {
              'customer_id': customerId,
              'address_id': addressId,
              'api_key': apiKey
            });
      } else {
        // Fetch first address from address list
        addressResponse = await dio.get('${appUri}/gws_customer_address',
            queryParameters: {'customer_id': customerId, 'api_key': apiKey});
      }

      var addressData = addressResponse.data;

      setState(() {
        // 根據 status 決定如何處理地址
        if (addressData['message'][0]['msg_status']) {
          customerAddress = addressData['customer_address'][0];
        } else {
          // 如果 status 為 false，選擇最新地址或其他邏輯
        }

        // print{'customerAddress: ${customerAddress} addressId：${addressId}，');
      });
    } catch (e) {
      print(e);
      // Handle exceptions or show error messages
    }
  }

  Future<Map<String, dynamic>?> fetchCountryAndZoneDetails(
      String countryId) async {
    try {
      // 獲取國家信息
      var countryResponse = await dio.get('$appUri/gws_country',
          queryParameters: {'country_id': countryId, 'api_key': apiKey});
      var countryData = countryResponse.data;

      // 檢查國家信息是否成功獲取
      if (countryData['message'][0]['msg_status'] == true) {
        // 獲取區域列表
        var zoneResponse = await dio.get('$appUri/gws_zone',
            queryParameters: {'country_id': countryId, 'api_key': apiKey});
        var zoneData = zoneResponse.data;

        // 檢查區域信息是否成功獲取
        if (zoneData['message'][0]['msg_status'] == true) {
          // 假定您需要第一個區域的信息
          var firstZone =
              zoneData['zones'].isNotEmpty ? zoneData['zones'][0] : null;

          if (firstZone != null) {
            // 返回國家和區域的詳細信息
            return {'country': countryData['country'][0], 'zone': firstZone};
          }
        }
      }
    } on DioException catch (e) {
      print(e);
    }
    return null;
  }

  Widget buildShippingMethodList(List<ShippingMethod> methods) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: ResponsiveText(
            '物流方式',
            baseFontSize: 34, // 字體大小
            fontWeight: FontWeight.bold, // 字體加粗
          ),
        ),
        ...methods.map((method) {
          if (methods.isNotEmpty) {
            _selectedShippingMethodCode = methods.first.sortOrder!;
          }
          return ListTile(
            leading: Radio<int>(
              value: method.sortOrder!,
              groupValue: _selectedShippingMethodCode, // 將 groupValue 設置為選中的值
              onChanged: (int? value) {
                setState(() {
                  _selectedShippingMethodCode = value!;
                  _selectedShippingCost = method.cost.toDouble();
                  totalAmount = _tempTotalAmount;
                  totalAmount = totalAmount + _selectedShippingCost;
                });
              },
            ),
            title: ResponsiveText(
              method.title,
              baseFontSize: 32, // 字體大小
            ),
            trailing: ResponsiveText(
              'NT\$${method.cost}',
              baseFontSize: 34, // 字體大小
              fontWeight: FontWeight.bold, // 字體加粗
            ),
            onTap: () {
              setState(() {
                _selectedShippingMethodCode = method.sortOrder;
                _selectedShippingCost = method.cost.toDouble();
                totalAmount = _tempTotalAmount;
                totalAmount = totalAmount + _selectedShippingCost;
              });
            },
          );
        }).toList(),
      ],
    );
  }

  Future<List<ShippingMethod>> fetchShippingMethods() async {
    final response = await dio.get(
      '${appUri}/gws_appshipping_methods/index',
      queryParameters: {
        'api_key': apiKey,
        'customer_id': customerId,
        'address_id': customerAddress!['address_id'],
      },
    );

    if (response.statusCode == 200) {
      final data = Map<String, dynamic>.from(response.data);
      if (data['message'][0]['msg_status'] == true) {
        List<ShippingMethod> shippingMethods = List<ShippingMethod>.from(
          data['shipping_methods'].map((item) => ShippingMethod.fromJson(item)),
        ).where((method) {
          // 確保 sortOrder 是正數並且沒有錯誤
          return !method.error;
        }).toList();
        return shippingMethods;
      }
    }
    throw Exception('Failed to load shipping methods');
  }

  Future<void> submitOrder() async {
    if (_selectedPaymentMethod == null || _selectedShippingMethodCode == null) {
      // 顯示警告對話框
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: ResponsiveText('溫馨提醒!', baseFontSize: 38),
            content: ResponsiveText(
              '您尚未選定付款方式或物流方式。',
              baseFontSize: 36,
              maxLines: 5,
            ),
            actions: <Widget>[
              TextButton(
                child: ResponsiveText('確定', baseFontSize: 36),
                onPressed: () {
                  Navigator.of(context).pop(); // 關閉對話框
                },
              ),
            ],
          );
        },
      );
      return;
    }

    // 構建請求體數據
    final orderData = {
      'address_id': customerAddress!['address_id'],
      'customer': customerData!['customer'],
      'products': products.map((product) {
        return {
          'product_id': product.productId,
          'quantity': product.quantity,
          'price': product.special != false ? product.special : product.price,
          'total': product.special != false
              ? product.special * product.quantity
              : product.price * product.quantity,
          'name': product.name,
          'options': product.options.map((option) {
            return {
              'product_option_id': option.productOptionId,
              'product_option_value_id': option.productOptionValueId,
              'type': option.type,
              'value': option.value,
              'name': option.name,
            };
          }).toList(),
        };
      }).toList(),
      'shipping_sort_order': _selectedShippingMethodCode,
      'payment_method': _selectedPaymentMethod,
      'shipping_cost': _selectedShippingCost,
      'totals': _extractTotalsFromProducts(products), // 提取 totals
      'amount': totalAmount,
    };

    // print(orderData['totals']);

    dio.post('${demoUrl}/api/product/order/data/${customerId}',
        data: orderData);

    final response =
        await dio.get('${demoUrl}/api/product/submit/${customerId}');

    if (response.statusCode == 200) {
      final responseData = response.data['data'];

      // print(
      // 'Order submitted successfully: ${responseData['order']['order_id']}');

      //TODO: 跳轉到付款頁面
      final htmlUrl =
          '${demoUrl}/api/product/payment?customerId=${customerId}&orderId=' +
              responseData['order']['order_id'] +
              '&api_key=${apiKey}';

      print(_selectedPaymentMethod);

      if (_selectedPaymentMethod == 'bank_transfer') {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  ShopPaymentBankTransferPage(htmlUrl: htmlUrl)),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ShopPaymentPage(htmlUrl: htmlUrl)),
        );
      }
    } else {
      print('Failed to submit order: ${response.statusCode}');
    }
  }

  Future<void> _fetchPaymentMethods() async {
    final response = await dio.get(
        '${appUri}/gws_apppayment_methods/index&customer_id=${customerId}&api_key=${apiKey}');

    print(response.data);

    if (response.statusCode == 200) {
      final data = response.data;
      final paymentMethods = data['payment_methods'] as List;

      setState(() {
        _dropdownItems = paymentMethods.map((method) {
          return DropdownMenuItem<String>(
            value: method['code'],
            child: Text(method['title']),
          );
        }).toList();
      });
    } else {
      throw Exception('Failed to load payment methods');
    }
  }

  // 從產品列表中提取 totals
  List<Map<String, dynamic>> _extractTotalsFromProducts(
      List<Product> products) {
    // 假設所有產品的 totals 是相同的，取第一個產品的 totals 作為範例
    if (products.isNotEmpty && products[0].totals.isNotEmpty) {
      return products[0].totals;
    }
    return [];
  }

  String splitByLengthAndJoin(String str, int length,
      {String separator = ' '}) {
    List<String> parts = [];
    for (int i = 0; i < str.length; i += length) {
      int end = (i + length < str.length) ? i + length : str.length;
      parts.add(str.substring(i, end));
    }
    return parts.join(separator);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('購物車'),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF4F4E4C),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty // 如果產品列表為空
              ? Center(
                  // 顯示購物車空的提示畫面
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.shopping_cart,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      InlineTextWidget(
                        '您的購物車是空的!',
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ResponsiveText(
                            '商品總計',
                            baseFontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                          ResponsiveText(
                            'NT\$${totalAmount.toStringAsFixed(0)}',
                            baseFontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                      color: Colors.grey, // 您可以選擇線的顏色
                      thickness: 0.5, // 線的厚度
                      height: 20, // 與其他元素的間距
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: ResponsiveText('付款方式',
                              baseFontSize: 34, fontWeight: FontWeight.bold),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              isDense: true, // Reduces the dropdown's height
                            ),
                            isExpanded: true,
                            value: _selectedPaymentMethod,
                            items: _dropdownItems,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedPaymentMethod = value;
                              });
                            },
                            hint: Text('選擇付款方式'),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: products.length + 2, // 添加1是为了显示地址信息
                        padding: const EdgeInsets.only(bottom: 100.0),
                        itemBuilder: (context, index) {
                          if (index == 0 && customerAddress != null) {
                            // print{customerAddress);
                            // 在列表的最上方显示地址信息
                            return FutureBuilder<Map<String, dynamic>?>(
                              future: fetchCountryAndZoneDetails(
                                  customerAddress!['country_id']),
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map<String, dynamic>?>
                                      snapshot) {
                                if (snapshot.hasData) {
                                  final countryDetails =
                                      snapshot.data!['country'];
                                  final zoneDetails = snapshot.data!['zone'];
                                  return ListTile(
                                    title: ResponsiveText('收貨地址',
                                        baseFontSize: 34,
                                        fontWeight: FontWeight.bold),
                                    subtitle: ResponsiveText(
                                      '${customerAddress!['firstname']} ${customerAddress!['lastname']} \n' +
                                          '${customerAddress!['address_1']} ${customerAddress!['address_2']} \n' +
                                          '${zoneDetails['name']}, ${countryDetails['name']} \n' +
                                          '${customerAddress!['postcode']}',
                                      baseFontSize: 30,
                                      maxLines: 10,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () async {
                                        // 編輯地址的邏輯

                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  AddressCartAddPage()),
                                        );
                                        // print('地址: $selectedAddress');
                                        // if (selectedAddress != null) {
                                        //   // 更新地址信息
                                        //   setState(() {
                                        //     fetchCustomerAddress(
                                        //         defaultAddressId:
                                        //             selectedAddress.id);
                                        //   });
                                        // }
                                      },
                                    ),
                                  );
                                } else {
                                  return const Text('No data');
                                }
                              },
                            );
                          } else if (index == products.length + 1) {
                            // 显示物流信息
                            return FutureBuilder<List<ShippingMethod>>(
                              future: fetchShippingMethods(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                      child: CircularProgressIndicator());
                                } else if (snapshot.hasData) {
                                  // 使用上面的 buildShippingMethodList 方法构建界面
                                  return buildShippingMethodList(
                                      snapshot.data!);
                                } else {
                                  return const Text(
                                      'No shipping methods available');
                                }
                              },
                            );
                          } else {
                            // 显示商品列表
                            final product = products[index - 1]; // 调整索引以获取正确的商品
                            return ListTile(
                              leading: Image.network(
                                '${imgUrl}' + product.thumbUrl,
                                width: 80,
                              ),
                              title: ResponsiveText(
                                product.name,
                                baseFontSize: 36,
                                maxLines: 4,
                              ),
                              subtitle: Row(
                                children: [
                                  ResponsiveText('數量: ${product.quantity}',
                                      baseFontSize: 28),
                                ],
                              ),
                              trailing: ResponsiveText(
                                  product.special != false
                                      ? 'NT\$' +
                                          (product.special * product.quantity)
                                              .toString()
                                      : 'NT\$' +
                                          (product.price * product.quantity)
                                              .toString(),
                                  baseFontSize: 28,
                                  fontWeight: FontWeight.bold),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
      bottomSheet: Container(
        color: Colors.white,
        width: double.infinity, // 容器宽度占满整个屏幕宽度
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: isLoading
              ? ElevatedButton(
                  onPressed: () {
                    submitOrder();
                  },
                  child: const InlineTextWidget(
                    '確定下訂單',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey, // 按钮背景颜色为灰色
                    foregroundColor: Color(0xFF4F4E4C), // 文本颜色为白色
                    minimumSize: Size(double.infinity, 36), // 按钮最小尺寸，宽度占满
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6), // 圆角矩形按钮
                    ),
                  ),
                )
              : products.isEmpty
                  ? ElevatedButton(
                      onPressed: () {
                        // 当购物车为空时，跳转到逛逛賣場
                        Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => MyApp()));
                      },
                      child: InlineTextWidget('逛逛賣場',
                          style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // 按钮背景颜色为蓝色
                        foregroundColor: Color(0xFF4F4E4C), // 文本颜色为白色
                        minimumSize: Size(double.infinity, 36), // 按钮最小尺寸，宽度占满
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        submitOrder();
                      },
                      child: InlineTextWidget('確定下訂單',
                          style: const TextStyle(
                              fontSize: 18, color: Color(0xFF4F4E4C))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // 按钮背景颜色为蓝色
                        foregroundColor: Color(0xFF4F4E4C), // 文本颜色为白色
                        minimumSize: Size(double.infinity, 36), // 按钮最小尺寸，宽度占满
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: Colors.black), // 圆角矩形按钮
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class Product {
  final String productId;
  final String name;
  final String thumbUrl;
  final int price;
  int quantity;
  final String cartId;
  final dynamic special;
  final List<Option> options; // 添加 options 属性
  final List<Map<String, dynamic>> totals; // 添加 totals 属性

  void incrementQuantity() {
    quantity++;
  }

  void decrementQuantity() {
    if (quantity > 0) {
      quantity--;
    }
  }

  Product({
    required this.productId,
    required this.name,
    required this.thumbUrl,
    required this.price,
    required this.quantity,
    required this.cartId,
    required this.special,
    required this.options, // 添加 options 参数
    required this.totals, // 添加 totals 参数
  });

  factory Product.fromJson(Map<String, dynamic> combinedJson) {
    // 解析 options
    List<Option> options = [];
    if (combinedJson['options'] != null) {
      var optionData = combinedJson['options'];
      if (optionData is List) {
        options = optionData.map((entry) {
          return Option(
            productOptionId: entry['product_option_id'],
            productOptionValueId: entry['product_option_value_id'],
            type: entry['type'],
            value: entry['value'],
            name: entry['name'],
          );
        }).toList();
      } else {
        // 处理其他意外类型
        print('Unexpected options data type: ${optionData.runtimeType}');
      }
    }

    // 解析 totals
    List<Map<String, dynamic>> totals = [];
    if (combinedJson['totals'] != null) {
      var totalsData = combinedJson['totals'];
      if (totalsData is List) {
        totals = totalsData.map((entry) {
          return {
            'code': entry['code'],
            'title': entry['title'],
            'text': entry['text'],
          };
        }).toList();
      } else {
        // 处理其他意外类型
        print('Unexpected totals data type: ${totalsData.runtimeType}');
      }
    }

    return Product(
      productId: combinedJson['product_id'],
      name: combinedJson['name'],
      thumbUrl: combinedJson['thumb'],
      price:
          int.parse(combinedJson['price'].replaceAll(RegExp(r'[^0-9\.]'), '')),
      quantity: int.parse(combinedJson['quantity']),
      cartId: combinedJson['cart_id'],
      special: combinedJson['special'] == false
          ? false
          : int.parse(
              combinedJson['special'].replaceAll(RegExp(r'[^0-9\.]'), '')),
      options: options, // 添加 options 初始化
      totals: totals, // 添加 totals 初始化
    );
  }
}

class Option {
  final String productOptionId;
  final String productOptionValueId;
  final String type;
  final String value;
  final String name;

  Option({
    required this.productOptionId,
    required this.productOptionValueId,
    required this.type,
    required this.value,
    required this.name,
  });
}

class ShippingMethod {
  String title;
  int cost;
  String code;
  bool error;
  int? sortOrder;

  ShippingMethod({
    required this.title,
    required this.code,
    required this.cost,
    required this.error,
    required this.sortOrder,
  });

  factory ShippingMethod.fromJson(Map<String, dynamic> json) {
    // 將 sort_order 字段轉換為整數
    var sortOrderString = json['sort_order']?.toString();
    int? sortOrder = int.tryParse(sortOrderString ?? '0');

    // 將 cost 字段轉換為整數
    var costString = json['cost']?.toString();
    int cost = int.tryParse(costString ?? '0') ?? 0;

    return ShippingMethod(
      title: json['title'],
      code: json['code'],
      cost: cost,
      error: json['error'],
      sortOrder: sortOrder ?? 0,
    );
  }
}
