import 'dart:async' show Future, StreamSubscription;

import 'package:in_app_purchase/in_app_purchase.dart';

class InAppPurchaseService {
  late StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  List<String> productIds;
  final Function errorMessageCallback;
  final Function rewardCallback;
  final Function successMessageCallback;
  final Function cancelCallback;

  InAppPurchaseService({
    required this.productIds,
    required this.errorMessageCallback,
    required this.rewardCallback,
    required this.successMessageCallback,
    required this.cancelCallback,
  });

  String currentProductId = 'all_toot_fruits';

  void init() {
    final Stream purchaseUpdated = InAppPurchase.instance.purchaseStream;

    _purchaseSubscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _purchaseSubscription.cancel();
      cancelCallback();
    }, onError: (err) {
      errorMessageCallback("Failed to update purchase.");
      cancelCallback();
    }) as StreamSubscription<List<PurchaseDetails>>;
  }

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        return;
      }

      if (purchaseDetails.status == PurchaseStatus.canceled) {
        cancelCallback();
        return;
      }

      if (purchaseDetails.status == PurchaseStatus.error) {
        await InAppPurchase.instance.completePurchase(purchaseDetails);
        errorMessageCallback("Failed to purchase product.");
        cancelCallback();
        return;
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchaseDetails);
        cancelCallback();
      }

      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }

        await rewardCallback();
      }
    }
  }

  Future<void> purchase(String type) async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      // The store cannot be reached or accessed.
      errorMessageCallback("The App Store cannot be reached.");
      cancelCallback();
    }

    final ProductDetails? productDetails = await getProduct();

    if (productDetails == null) {
      errorMessageCallback("The App Store couldn't find this product.");
      cancelCallback();
      return;
    }

    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);

    if (type == 'consumable') {
      InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
    } else if (type == 'nonconsumable') {
      InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  Future<void> restore() async {
    await InAppPurchase.instance.restorePurchases();
    successMessageCallback("Purchases restored.");
  }

  Future<ProductDetails?> getProduct() async {
    final Set<String> kIds = <String>{currentProductId};

    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails(kIds);

    if (response.notFoundIDs.isNotEmpty) {
      errorMessageCallback("Can't find selected product in App Store.");
    }
    List<ProductDetails> products = response.productDetails;

    if (products.isNotEmpty) {
      return products.first;
    }

    return null;
  }
}
