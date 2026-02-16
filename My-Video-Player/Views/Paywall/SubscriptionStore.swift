//
//  SubscriptionStore.swift
//  Truth Or Dare
//
//  Created by Shivshankar T Tiwari on 14/11/25.
//

import Foundation
import os.log
import StoreKit
import Combine

typealias Transaction = StoreKit.Transaction
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

enum StoreError:LocalizedError{
    case failedVerification
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Your purchase could not be verified by the App Store."
        }
    }
}


class SubscriptionStore: ObservableObject {
    
    @Published private(set) var isReady: Bool = false
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionGroupStatus: RenewalState?
    @Published private(set) var purchasedTransactions: [Transaction] = []
    @Published var toSubscription: Bool = false
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    
    private let productIds: [String] = ["com.wildrr.app.weekly", "com.wildrr.app.yearly", "com.wildrr.app.lifetime"]
    
    /// Determines if the user is subscribed based on their subscription group status.
    /// Returns true if the subscription group status is either .subscribed or .inGracePeriod.
    var isSubscribed: Bool {
        return subscriptionGroupStatus == .subscribed || subscriptionGroupStatus == .inGracePeriod
    }
    
    init() {
        //Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()
        
        Task {
            //During store initialization, request products from the App Store.
            await requestProducts()
            
            //Deliver products that the customer purchases.
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
 
    /// Listens for transactions and processes them accordingly.
    ///
    /// This method sets up a background task to listen for transaction updates and processes them as they occur.
    /// For each transaction update received, it verifies the transaction, updates the customer's product status, and finishes the transaction.
    /// - Returns: A `Task` representing the asynchronous process of listening for and handling transactions.
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            //Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    //Deliver products to the user.
                    await self.updateCustomerProductStatus()
                    
                    //Always finish a transaction.
                    await transaction.finish()
                } catch {
                    //StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    debugPrint("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    /// Requests product information from the App Store.
    ///
    /// This method asynchronously fetches product information from the App Store using the provided product IDs.
    /// It filters the retrieved products based on their type and sorts them by price in ascending order.
    /// The results are then updated in the `subscriptions` property of the `SubscriptionStore`.
    @MainActor
    func requestProducts() async {
        do {
            //Request products from the App Store using the identifiers that stored in productIds
            let storeProducts = try await Product.products(for: productIds)
            
            var newSubscriptions: [Product] = []
            
            //Filter the products into categories based on their type.
            for product in storeProducts {
                switch product.type {
                case .autoRenewable,.nonConsumable:
                    newSubscriptions.append(product)
                default:
                    //Ignore this product.
                    debugPrint("Unknown product encountered: \(product.id)")
                }
            }
            
            //Sort each product category by price, lowest to highest, to update the store.
            subscriptions = sortByPrice(newSubscriptions)
            
            // Log success message
           // debugPrint("Products successfully requested from the App Store")
        } catch {
            // Log error message
            debugPrint("Failed product request from the App Store server: \(error)")
        }
    }
    
    /// Initiates the purchase of a specified product.
    ///
    /// This method asynchronously begins the purchase process for the given `Product`.
    /// It handles the purchase result and updates the customer's product status accordingly.
    /// If the purchase is successful, it returns the transaction object; otherwise, it logs the appropriate message.
    /// - Parameter product: The `Product` to be purchased.
    /// - Returns: An optional `Transaction` object representing the purchase transaction if successful; otherwise, `nil`.
    func purchase(_ product: Product) async throws -> Transaction? {
        //Begin purchasing the `Product` the user selects.
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            //Check whether the transaction is verified. If it isn't,
            //this function rethrows the verification error.
            let transaction = try checkVerified(verification)
            
            //The transaction is verified. Deliver content to the user.
            await updateCustomerProductStatus()
            
            //Always finish a transaction.
            await transaction.finish()
            
            // Log success message
            debugPrint("Product purchased successfully: \(product.id)")
            
            return transaction
        case .userCancelled, .pending:
            // Log cancellation message
            debugPrint("User cancelled the purchase: \(product.id)")
            
            return nil
        default:
            // Log default case message
            debugPrint("Unknown result for product purchase: \(product.id)")
            
            return nil
        }
    }

    /// Determines if the user has purchased a specific product.
    ///
    /// This method asynchronously checks whether the user has purchased the given `Product`.
    /// For auto-renewable subscription products, it verifies the presence of the product in the `purchasedSubscriptions` array.
    /// - Parameter product: The `Product` to check for purchase.
    /// - Returns: A boolean indicating whether the user has purchased the specified product.
    func isPurchased(_ product: Product) async throws -> Bool {
        //Determine whether the user purchases a given product.
        switch product.type {
        case .autoRenewable:
            return purchasedSubscriptions.contains(product)
        default:
            return false
        }
    }

    /// Checks the verification result of a JSON Web Signature (JWS).
    ///
    /// This method synchronously checks whether the JWS passes StoreKit verification.
    /// It evaluates the `VerificationResult` and returns the verified content or throws a verification error.
    /// - Parameter result: The `VerificationResult` to be checked.
    /// - Returns: The verified content.
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            //StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            //The result is verified. Return the unwrapped value.
            return safe
        }
    }
    
    /// Updates the customer's product status, including their purchased auto-renewable subscriptions.
    ///
    /// This function iterates through the user's purchased products, verifies transactions, and updates the store information accordingly.
    /// It also checks the subscription group status to determine the subscription state (new, active, or inactive).
   // @MainActor
//    func updateCustomerProductStatus() async {
//        var purchasedSubscriptions: [Product] = []
//        var purchasedTransactions: [Transaction] = []
//
//        //Iterate through all of the user's purchased products.
//        for await result in Transaction.currentEntitlements {
//            do {
//                //Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
//                let transaction = try checkVerified(result)
//
//                //Check the `productType` of the transaction and get the corresponding product from the store.
//                switch transaction.productType {
//                case .autoRenewable,.nonConsumable:
//                    if let subscription = subscriptions.first(where: { $0.id == transaction.productID }) {
//                        purchasedSubscriptions.append(subscription)
//                        purchasedTransactions.append(transaction)
//                    }
//                default:
//                    break
//                }
//            } catch {
//                // Log the error when a verification fails.
//                debugPrint("Transaction verification failed: \(error)")
//            }
//        }
//
//        //Update the store information with auto-renewable subscription products.
//        self.purchasedSubscriptions = purchasedSubscriptions
//        self.purchasedTransactions = purchasedTransactions
//
//        //Check the `subscriptionGroupStatus` to learn the auto-renewable subscription state to determine whether the customer
//        //is new (never subscribed), active, or inactive (expired subscription). This app has only one subscription
//        //group, so products in the subscriptions array all belong to the same group. The statuses that
//        //`product.subscription.status` returns apply to the entire subscription group.
//        subscriptionGroupStatus = try? await subscriptions.first?.subscription?.status.first?.state
//
//
//        // Log success message
//       // debugPrint("Customer product status updated successfully",subscriptionGroupStatus == .subscribed)
//
//        Global.shared.storeIsUserPro(subscriptionGroupStatus == .subscribed)
//
//        // Update isReady status to notifiy it's ready to use
//        isReady = true
//    }
    
    @MainActor
    func updateCustomerProductStatus() async {
        var purchasedSubscriptions: [Product] = []
        var purchasedTransactions: [Transaction] = []
        var hasLifetimePurchase = false  // Flag to track lifetime plan
        
        // Fetch all transactions and sort them by `purchaseDate` (newest first)
        var transactions: [Transaction] = []
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                transactions.append(transaction)
            } catch {
                debugPrint("Transaction verification failed: \(error)")
            }
        }
        
        // Sort transactions by `purchaseDate` (newest first)
        transactions.sort { $0.purchaseDate > $1.purchaseDate }

        // Iterate over transactions in sorted order
        for transaction in transactions {
            switch transaction.productType {
            case .autoRenewable:
                if let subscription = subscriptions.first(where: { $0.id == transaction.productID }) {
                    purchasedSubscriptions.append(subscription)
                    purchasedTransactions.append(transaction)
                }
            case .nonConsumable:
                if subscriptions.first(where: { $0.id == transaction.productID }) != nil {
                    hasLifetimePurchase = true  // Set flag for lifetime purchase
                    purchasedTransactions.append(transaction)
                }
            default:
                break
            }
        }

        // Update the store information with sorted auto-renewable subscription products.
        self.purchasedSubscriptions = purchasedSubscriptions
        self.purchasedTransactions = purchasedTransactions

        // Get the most recent transaction's subscription state
        let isSubscribed = try? await purchasedSubscriptions.first?.subscription?.status.first?.state == .subscribed

        // If the lifetime plan is purchased, set user as Pro immediately
        let userIsPro = isSubscribed == true || hasLifetimePurchase

        // Log success message
     //   debugPrint("Customer product status updated successfully", userIsPro)

        // Update user pro status based on latest transaction
         Global.shared.storeIsUserPro(userIsPro)
        
        // Notify that it's ready to use
        isReady = true
    }

    
    ///  Sorts an array of `Product` objects based on their prices in ascending order.
    /// - Parameter products: An array of `Product` objects to be sorted by price.
    /// - Returns: An array of `Product` objects sorted by price in ascending order.
    func sortByPrice(_ products: [Product]) -> [Product] {
        products.sorted(by: { return $0.price > $1.price })
    }
    
    /// Initiates the restoration of previous purchases from the App Store.
    func restorePurchases() async throws {
        //This call displays a system prompt that asks users to authenticate with their App Store credentials.
        //Call this function only in response to an explicit user action, such as tapping a button.
        try await AppStore.sync()
    }
}
