//
//  LGOBluetoothScanPlugin.m
//  plugin

#import "LGOBluetoothScanPlugin.h"
#import <LEGO-SDK/LGOCore.h>
#import <CoreBluetooth/CoreBluetooth.h>
@interface LGOBluetoothScanRequest: LGORequest
@property (nonatomic, copy) NSString *opt;
//@property (nonatomic, copy) NSDictionary *target;
//@property (nonatomic, copy) NSArray *scanServiceUUIDs;
//@property (nonatomic, copy) NSDictionary *scanServiceOptions;
//@property (nonatomic, copy) NSDictionary *connectPeripheralOptions;
//@property (nonatomic, copy) NSString *connectPeripheralUUIDString;
@property (nonatomic, copy) NSDictionary *scanTargetServiceParams;
@property (nonatomic, copy) NSDictionary *connectTargetPeripheralParams;
// TODO: merage scan or discover or connect paramers into a dic
@end

@implementation LGOBluetoothScanRequest

@end

@interface LGOBluetoothScanResponse: LGOResponse

@property (nonatomic, strong) NSString *text;
@property (nonatomic, assign) NSInteger stateCode;
@property (nonatomic, copy) NSArray<NSString *> *discoverPeripherals;
@property (nonatomic, copy) NSArray<NSString *> *connectedPeripheralIDs;
@property (nonatomic, copy) NSDictionary<NSString *, NSArray *> *discoverServices;
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary<NSString *, NSArray *> *> *discoverCharacteristics;
@end

@implementation LGOBluetoothScanResponse

- (NSDictionary *)resData {
    return @{
             @"text": self.text ?: @"",
             @"stateCode": @(self.stateCode),
             @"discoverPeripherals": self.discoverPeripherals ?: @{},
             @"connectedPeripheralIDs": self.connectedPeripheralIDs ?: @{},
             @"discoverServices": self.discoverServices ?: @{},
             @"discoverCharacteristics": self.discoverCharacteristics ?: @{},
             };
}

@end


@interface LGOBluetoothScanOperation: LGORequestable

@property (nonatomic, strong) LGOBluetoothScanRequest *request;
@property (nonatomic, copy) LGORequestableAsynchronizeBlock callbackBlock;
@end

@interface LGOBluetoothScanDelegateHandler: NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
+ (instancetype)sharedInstance;
@property (nonatomic, strong) LGOBluetoothScanOperation *operation;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CBPeripheral *> *discoverPeripherals;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CBPeripheral *> *connectedPeripheralIDs;
- (void)startScanWithServices:(NSArray<CBUUID *> *)serviceUUIDs option:(NSDictionary<NSString *,id> *)options;
- (void)stopScan;
- (void)connectPeripheral:(CBPeripheral *)peripheral option:(NSDictionary *)option;
- (void)dicoverServices:(NSArray *)servicesUUIDs peripheral:(CBPeripheral *)peripheral;
- (void)discoverCharacteristics:(NSArray *)characteristicUUIDs forService:(CBService *)service onPeripheral:(CBPeripheral *)peripheral;
@end

@implementation LGOBluetoothScanOperation

- (void)requestAsynchronize:(LGORequestableAsynchronizeBlock)callbackBlock {
    self.callbackBlock = callbackBlock;
    [LGOBluetoothScanDelegateHandler sharedInstance].operation = self;
    if ([self.request.opt isEqualToString:@"startScanPeripheral"]) {
        if ([self.request.scanTargetServiceParams isKindOfClass:[NSDictionary class]]) {
            [[LGOBluetoothScanDelegateHandler sharedInstance] startScanWithServices:self.request.scanTargetServiceParams[@"scanServiceUUIDs"] option:self.request.scanTargetServiceParams[@"scanServiceOptions"]];
        } else {
            [[LGOBluetoothScanDelegateHandler sharedInstance] startScanWithServices:nil option:nil];
        }
    }
    else if ([self.request.opt isEqualToString:@"stopScanPeripheral"]) {
        [[LGOBluetoothScanDelegateHandler sharedInstance] stopScan];
    } else if ([self.request.opt isEqualToString:@"startConnectPeripheral"]) {
        if ([self.request.connectTargetPeripheralParams[@"connectPeripheralUUIDString"] isKindOfClass:[NSString class]]) {
            CBPeripheral *peripheral = [LGOBluetoothScanDelegateHandler sharedInstance].discoverPeripherals[self.request.connectTargetPeripheralParams[@"connectPeripheralUUIDString"]];
            if (peripheral) {
                if ([peripheral isKindOfClass:[CBPeripheral class]]) {
                    if ([self.request.connectTargetPeripheralParams isKindOfClass:[NSDictionary class]]) {
                        [[LGOBluetoothScanDelegateHandler sharedInstance] connectPeripheral:peripheral option:self.request.connectTargetPeripheralParams[@"connectPeripheralOptions"]];
                    } else {
                        [[LGOBluetoothScanDelegateHandler sharedInstance] connectPeripheral:peripheral option:nil];
                    }
                } else {
                    self.callbackBlock([[LGOBluetoothScanResponse new] reject:[NSError errorWithDomain:@"Plugin.BluetoothScan" code:-902 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"can not find corresponding Peripheral with UUIDString %@", self.request.connectTargetPeripheralParams[@"connectPeripheralUUIDString"]]}]]);
                }
            } else {
                self.callbackBlock([[LGOBluetoothScanResponse new] reject:[NSError errorWithDomain:@"Plugin.BluetoothScan" code:-902 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"can not find corresponding Peripheral with UUIDString %@", self.request.connectTargetPeripheralParams[@"connectPeripheralUUIDString"]]}]]);
            }
        } else {
            self.callbackBlock([[LGOBluetoothScanResponse new] reject:[NSError errorWithDomain:@"Plugin.BluetoothScan" code:-901 userInfo:@{NSLocalizedDescriptionKey : @"startConnectPeripheral opt should have connectPeripheralUUIDString"}]]);
        }
    } else if ([self.request.opt isEqualToString:@"startDiscoverService"]) {
        
    }
}
@end

@interface LGOBluetoothScanDelegateHandler()
@property (nonatomic, strong) CBCentralManager *centralManager;
@end
@implementation LGOBluetoothScanDelegateHandler
static LGOBluetoothScanDelegateHandler *singleton = nil;

typedef NS_ENUM(NSInteger, LGOBluetoothScanState) {
    LGOBluetoothScanStateUnknown = -1,
    LGOBluetoothScanStateResetting = -2,
    LGOBluetoothScanStateUnsupported = -3,
    LGOBluetoothScanStateUnauthorized = -4,
    LGOBluetoothScanStatePoweredOff = -5,
    LGOBluetoothScanStatePoweredOn = 1,
    LGOBluetoothScanStateWillRestoreState = 2,
    LGOBluetoothScanStateDidDiscoverPeripheral = 3,
    LGOBluetoothScanStateDidConnectPeripheral = 4,
    LGOBluetoothScanStateDidFailToConnectPeripheral = -6,
    LGOBluetoothScanStateDidDisconnectPeripheral = 5,
    LGOBluetoothScanStateDidDiscoverServices = 6,
    LGOBluetoothScanStateDidDiscoverCharacteristicsForService = 7,
};


+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[super allocWithZone:NULL] init];
    });
    return singleton;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [LGOBluetoothScanDelegateHandler sharedInstance];
}

- (id)copyWithZone:(struct _NSZone *)zone {
    return [LGOBluetoothScanDelegateHandler sharedInstance];
}

- (NSMutableDictionary *)discoverPeripherals {
    if (! _discoverPeripherals) {
        _discoverPeripherals = [NSMutableDictionary dictionary];
    }
    return _discoverPeripherals;
}

#pragma mark Utils
- (void)startScanWithServices:(NSArray<CBUUID *> *)serviceUUIDs option:(NSDictionary<NSString *,id> *)options {
    [self stopScan];
    if (self.centralManager.state == CBCentralManagerStatePoweredOn) {
            [self.centralManager scanForPeripheralsWithServices:serviceUUIDs options:options];
    }
}

- (void)stopScan {
    if (self.centralManager) {
        [self.centralManager stopScan];
    }
}

- (CBCentralManager *)centralManager {
    if (! _centralManager) {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:[LGOBluetoothScanDelegateHandler sharedInstance] queue:dispatch_get_main_queue()];
    }
    return _centralManager;
}

- (void)connectPeripheral:(CBPeripheral *)peripheral option:(NSDictionary *)option {
    peripheral.delegate = self;
    [self.centralManager connectPeripheral:peripheral options:option];
}

- (void)dicoverServices:(NSArray *)servicesUUIDs peripheral:(CBPeripheral *)peripheral {
    [peripheral discoverServices:servicesUUIDs];
}

- (void)discoverCharacteristics:(NSArray *)characteristicUUIDs forService:(CBService *)service onPeripheral:(CBPeripheral *)peripheral {
    [peripheral discoverCharacteristics:characteristicUUIDs forService:service];
}
#pragma mark CBCentralManager delegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state != CBCentralManagerStatePoweredOn) {
        switch (central.state) {
            case CBCentralManagerStateUnknown: {
                if (self.operation.callbackBlock) {
                    self.operation.callbackBlock([[LGOBluetoothScanResponse new] reject:[NSError errorWithDomain:@"Plugin.BluetoothScan" code:-1 userInfo:@{NSLocalizedDescriptionKey : @"CBCentralManagerStateUnknown"}]]);
                }
            }
                break;
                
            case CBCentralManagerStateResetting: {
                self.operation.callbackBlock([[LGOBluetoothScanResponse new] reject:[NSError errorWithDomain:@"Plugin.BluetoothScan" code:-1 userInfo:@{NSLocalizedDescriptionKey : @"CBCentralManagerStateResetting"}]]);
                break;
            }
            case CBCentralManagerStateUnsupported: {
                self.operation.callbackBlock([[LGOBluetoothScanResponse new] reject:[NSError errorWithDomain:@"Plugin.BluetoothScan" code:-1 userInfo:@{NSLocalizedDescriptionKey : @"CBCentralManagerStateUnsupported"}]]);
                break;
            }
            case CBCentralManagerStateUnauthorized: {
                self.operation.callbackBlock([[LGOBluetoothScanResponse new] reject:[NSError errorWithDomain:@"Plugin.BluetoothScan" code:-1 userInfo:@{NSLocalizedDescriptionKey : @"CBCentralManagerStateUnauthorized"}]]);
                break;
            }
            case CBCentralManagerStatePoweredOff: {
                self.operation.callbackBlock([[LGOBluetoothScanResponse new] reject:[NSError errorWithDomain:@"Plugin.BluetoothScan" code:-1 userInfo:@{NSLocalizedDescriptionKey : @"CBCentralManagerStatePoweredOff"}]]);
                break;
            }
        }
    } else {
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *, id> *)dict {
    LGOBluetoothScanResponse *response = [LGOBluetoothScanResponse new];
    response.stateCode = LGOBluetoothScanStateWillRestoreState;
    self.operation.callbackBlock([response accept:dict]);
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if (peripheral && peripheral.identifier.UUIDString) {
        [self.discoverPeripherals setObject:peripheral forKey:peripheral.identifier.UUIDString];
    }
    LGOBluetoothScanResponse *response = [LGOBluetoothScanResponse new];
    response.stateCode = LGOBluetoothScanStateDidDiscoverPeripheral;
    response.discoverPeripherals = self.discoverPeripherals.allKeys.copy;
    self.operation.callbackBlock([response accept:nil]);
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    if (peripheral && peripheral.identifier.UUIDString) {
        [self.connectedPeripheralIDs setObject:peripheral forKey:peripheral.identifier.UUIDString];
        LGOBluetoothScanResponse *response = [LGOBluetoothScanResponse new];
        response.stateCode = LGOBluetoothScanStateDidConnectPeripheral;
        response.connectedPeripheralIDs = self.connectedPeripheralIDs.allKeys.copy;
        self.operation.callbackBlock([response accept:nil]);
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    LGOBluetoothScanResponse *response = [LGOBluetoothScanResponse new];
    response.stateCode = LGOBluetoothScanStateDidFailToConnectPeripheral;
    self.operation.callbackBlock([response reject:error]);
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    if (peripheral && peripheral.identifier.UUIDString) {
        [self.connectedPeripheralIDs removeObjectForKey:peripheral.identifier.UUIDString];
        LGOBluetoothScanResponse *response = [LGOBluetoothScanResponse new];
        response.stateCode = LGOBluetoothScanStateDidDisconnectPeripheral;
        self.operation.callbackBlock([response accept:nil]);
    }
}

#pragma mark CBPeripheral delegate
- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
    if (error) {
        LGOBluetoothScanResponse *response = [LGOBluetoothScanResponse new];
        response.stateCode = LGOBluetoothScanStateDidDiscoverServices;
        self.operation.callbackBlock([response reject:error]);
    } else {
        if (peripheral && peripheral.identifier.UUIDString && peripheral.services) {
            NSMutableArray *servicesUUIDStrings = [NSMutableArray array];
            [peripheral.services enumerateObjectsUsingBlock:^(CBService * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj isKindOfClass:[CBService class]] && obj.UUID.UUIDString) {
                    [servicesUUIDStrings addObject:obj.UUID.UUIDString];
                }
            }];
            NSDictionary *discoverServices = [NSDictionary dictionaryWithObject:servicesUUIDStrings forKey:peripheral.identifier.UUIDString];
            LGOBluetoothScanResponse *response = [LGOBluetoothScanResponse new];
            response.stateCode = LGOBluetoothScanStateDidDiscoverServices;
            response.discoverServices = discoverServices;
            self.operation.callbackBlock([response accept:nil]);
        }
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error {
    if (error) {
        LGOBluetoothScanResponse *response = [LGOBluetoothScanResponse new];
        response.stateCode = LGOBluetoothScanStateDidDiscoverCharacteristicsForService;
        self.operation.callbackBlock([response reject:error]);
    } else {
        if (peripheral && peripheral.identifier.UUIDString && service && service.characteristics) {
            NSMutableArray *discoverCharacteristics = [NSMutableArray array];
            [service.characteristics enumerateObjectsUsingBlock:^(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj isKindOfClass:[CBCharacteristic class]] && obj.UUID.UUIDString) {
                    [discoverCharacteristics addObject:obj.UUID.UUIDString];
                }
            }];
            NSDictionary *serviceMapCharacteristics = @{service.UUID.UUIDString : discoverCharacteristics ?: @[]};
            NSDictionary *peripheralMapService = @{peripheral.identifier.UUIDString : serviceMapCharacteristics};
            LGOBluetoothScanResponse *response = [LGOBluetoothScanResponse new];
            response.stateCode = LGOBluetoothScanStateDidDiscoverCharacteristicsForService;
            response.discoverCharacteristics = peripheralMapService.copy;
            self.operation.callbackBlock([response accept:nil]);

        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {

}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error {
    
}

- (void)peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral {
    
}

@end

@implementation LGOBluetoothScanPlugin

- (LGORequestable *)buildWithDictionary:(NSDictionary *)dictionary context:(LGORequestContext *)context {
    LGOBluetoothScanOperation *operation = [LGOBluetoothScanOperation new];
    operation.request = [LGOBluetoothScanRequest new];
    operation.request.opt = [dictionary[@"opt"] isKindOfClass:[NSString class]] ? dictionary[@"opt"] : @"";
    operation.request.scanTargetServiceParams = [dictionary[@"scanTargetServiceParams"] isKindOfClass:[NSDictionary class]] ? dictionary[@"scanTargetServiceParams"] : @{};
    operation.request.connectTargetPeripheralParams = [dictionary[@"connectTargetPeripheralParams"] isKindOfClass:[NSDictionary class]] ? dictionary[@"connectTargetPeripheralParams"] : @{};
    return operation;
}

- (LGORequestable *)buildWithRequest:(LGORequest *)request {
    if ([request isKindOfClass:[LGOBluetoothScanRequest class]]) {
        LGOBluetoothScanOperation *operation = [LGOBluetoothScanOperation new];
        operation.request = (LGOBluetoothScanRequest *)request;
        return operation;
    }
    return nil;
}

+ (void)load {
    [[LGOCore modules] addModuleWithName:@"Plugin.BluetoothScan" instance:[self new]];
}

@end
