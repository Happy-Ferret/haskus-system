{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE DeriveAnyClass #-}

-- | OpenCL device module
module ViperVM.Arch.OpenCL.Device
   ( Device(..)
   , DeviceInfo(..)
   , DeviceType(..)
   , DeviceFPConfig(..)
   , DeviceExecCapability(..)
   , DeviceMemCacheType(..)
   , DeviceLocalMemType(..)
   , CommandQueueProperty(..)
   , CommandQueueProperties
   , isDeviceLittleEndian
   , isDeviceLittleEndian'
   , getDeviceGlobalMemSize
   , getDeviceGlobalMemSize'
   , getDeviceName
   , getDeviceName'
   , getDeviceVendor
   , getDeviceVendor'
   , getDeviceType
   , getDeviceType'
   , allDeviceTypes
   , getDeviceEndianness
   , getDeviceQueueProperties
   , getDeviceQueueProperties'
   )
where

import qualified ViperVM.Format.Binary.BitSet as BitSet
import ViperVM.Format.Binary.BitSet (BitSet, CBitSet)
import ViperVM.Format.Binary.Word
import ViperVM.Format.String (peekCString)
import ViperVM.Format.Binary.Ptr (Ptr, castPtr, nullPtr)
import ViperVM.Format.Binary.Endianness
import ViperVM.Format.Binary.Enum

import ViperVM.Arch.OpenCL.Types
import ViperVM.Arch.OpenCL.Entity
import ViperVM.Arch.OpenCL.Library
import ViperVM.Arch.OpenCL.Error

import Data.Ord (comparing)
import Foreign.Marshal.Alloc (alloca,allocaBytes)
import Foreign.Storable (peek, sizeOf)

-- | Device
data Device = Device Library Device_ deriving (Eq)

instance Ord Device where
   compare = comparing unwrap

instance Entity Device where 
   unwrap (Device _ x) = x
   cllib (Device l _) = l
   retain _ = return ()
   release _ = return ()

-- | Device information
data DeviceInfo
   = CL_DEVICE_TYPE
   | CL_DEVICE_VENDOR_ID
   | CL_DEVICE_MAX_COMPUTE_UNITS
   | CL_DEVICE_MAX_WORK_ITEM_DIMENSIONS
   | CL_DEVICE_MAX_WORK_GROUP_SIZE
   | CL_DEVICE_MAX_WORK_ITEM_SIZES
   | CL_DEVICE_PREFERRED_VECTOR_WIDTH_CHAR
   | CL_DEVICE_PREFERRED_VECTOR_WIDTH_SHORT
   | CL_DEVICE_PREFERRED_VECTOR_WIDTH_INT
   | CL_DEVICE_PREFERRED_VECTOR_WIDTH_LONG
   | CL_DEVICE_PREFERRED_VECTOR_WIDTH_FLOAT
   | CL_DEVICE_PREFERRED_VECTOR_WIDTH_DOUBLE
   | CL_DEVICE_MAX_CLOCK_FREQUENCY
   | CL_DEVICE_ADDRESS_BITS
   | CL_DEVICE_MAX_READ_IMAGE_ARGS
   | CL_DEVICE_MAX_WRITE_IMAGE_ARGS
   | CL_DEVICE_MAX_MEM_ALLOC_SIZE
   | CL_DEVICE_IMAGE2D_MAX_WIDTH
   | CL_DEVICE_IMAGE2D_MAX_HEIGHT
   | CL_DEVICE_IMAGE3D_MAX_WIDTH
   | CL_DEVICE_IMAGE3D_MAX_HEIGHT
   | CL_DEVICE_IMAGE3D_MAX_DEPTH
   | CL_DEVICE_IMAGE_SUPPORT
   | CL_DEVICE_MAX_PARAMETER_SIZE
   | CL_DEVICE_MAX_SAMPLERS
   | CL_DEVICE_MEM_BASE_ADDR_ALIGN
   | CL_DEVICE_MIN_DATA_TYPE_ALIGN_SIZE
   | CL_DEVICE_SINGLE_FP_CONFIG
   | CL_DEVICE_GLOBAL_MEM_CACHE_TYPE
   | CL_DEVICE_GLOBAL_MEM_CACHELINE_SIZE
   | CL_DEVICE_GLOBAL_MEM_CACHE_SIZE
   | CL_DEVICE_GLOBAL_MEM_SIZE
   | CL_DEVICE_MAX_CONSTANT_BUFFER_SIZE
   | CL_DEVICE_MAX_CONSTANT_ARGS
   | CL_DEVICE_LOCAL_MEM_TYPE
   | CL_DEVICE_LOCAL_MEM_SIZE
   | CL_DEVICE_ERROR_CORRECTION_SUPPORT
   | CL_DEVICE_PROFILING_TIMER_RESOLUTION
   | CL_DEVICE_ENDIAN_LITTLE
   | CL_DEVICE_AVAILABLE
   | CL_DEVICE_COMPILER_AVAILABLE
   | CL_DEVICE_EXECUTION_CAPABILITIES
   | CL_DEVICE_QUEUE_PROPERTIES
   | CL_DEVICE_NAME
   | CL_DEVICE_VENDOR
   | CL_DRIVER_VERSION
   | CL_DEVICE_PROFILE
   | CL_DEVICE_VERSION
   | CL_DEVICE_EXTENSIONS
   | CL_DEVICE_PLATFORM
   | CL_DEVICE_DOUBLE_FP_CONFIG
   | CL_DEVICE_HALF_FP_CONFIG
   | CL_DEVICE_PREFERRED_VECTOR_WIDTH_HALF
   | CL_DEVICE_HOST_UNIFIED_MEMORY
   | CL_DEVICE_NATIVE_VECTOR_WIDTH_CHAR
   | CL_DEVICE_NATIVE_VECTOR_WIDTH_SHORT
   | CL_DEVICE_NATIVE_VECTOR_WIDTH_INT
   | CL_DEVICE_NATIVE_VECTOR_WIDTH_LONG
   | CL_DEVICE_NATIVE_VECTOR_WIDTH_FLOAT
   | CL_DEVICE_NATIVE_VECTOR_WIDTH_DOUBLE
   | CL_DEVICE_NATIVE_VECTOR_WIDTH_HALF
   | CL_DEVICE_OPENCL_C_VERSION
   | CL_DEVICE_LINKER_AVAILABLE
   | CL_DEVICE_BUILT_IN_KERNELS
   | CL_DEVICE_IMAGE_MAX_BUFFER_SIZE
   | CL_DEVICE_IMAGE_MAX_ARRAY_SIZE
   | CL_DEVICE_PARENT_DEVICE
   | CL_DEVICE_PARTITION_MAX_SUB_DEVICES
   | CL_DEVICE_PARTITION_PROPERTIES
   | CL_DEVICE_PARTITION_AFFINITY_DOMAIN
   | CL_DEVICE_PARTITION_TYPE
   | CL_DEVICE_REFERENCE_COUNT
   | CL_DEVICE_PREFERRED_INTEROP_USER_SYNC
   | CL_DEVICE_PRINTF_BUFFER_SIZE
   | CL_DEVICE_IMAGE_PITCH_ALIGNMENT
   | CL_DEVICE_IMAGE_BASE_ADDRESS_ALIGNMENT
   deriving (Enum)

instance CEnum DeviceInfo where
   fromCEnum x = fromIntegral (0x1000 + fromEnum x)
   toCEnum x   = toEnum (fromIntegral x - 0x1000)

-- | Device type
data DeviceType
   = CL_DEVICE_TYPE_DEFAULT
   | CL_DEVICE_TYPE_CPU
   | CL_DEVICE_TYPE_GPU
   | CL_DEVICE_TYPE_ACCELERATOR
   | CL_DEVICE_TYPE_CUSTOM
   deriving (Eq,Show,Bounded,Enum,CBitSet)

type DeviceTypeSet = BitSet Word64 DeviceType

-- | List of all device types
allDeviceTypes :: DeviceTypeSet
allDeviceTypes = BitSet.fromList
   [ CL_DEVICE_TYPE_CPU 
   , CL_DEVICE_TYPE_GPU
   , CL_DEVICE_TYPE_ACCELERATOR
   , CL_DEVICE_TYPE_CUSTOM
   ]

-- | Device floating-point unit configuration
data DeviceFPConfig
   = CL_FP_DENORM
   | CL_FP_INF_NAN
   | CL_FP_ROUND_TO_NEAREST
   | CL_FP_ROUND_TO_ZERO
   | CL_FP_ROUND_TO_INF
   | CL_FP_FMA
   | CL_FP_SOFT_FLOAT
   | CL_FP_CORRECTLY_ROUNDED_DIVIDE_SQRT
   deriving (Show, Bounded, Eq, Ord, Enum, CBitSet)

-- | Device execution capabilities
data DeviceExecCapability
   = CL_EXEC_KERNEL
   | CL_EXEC_NATIVE_KERNEL
   deriving (Show, Bounded, Eq, Ord, Enum, CBitSet)

-- | Device cache memory type
data DeviceMemCacheType
   = CL_NONE
   | CL_READ_ONLY_CACHE
   | CL_READ_WRITE_CACHE
   deriving (Show,Enum)

instance CEnum DeviceMemCacheType where
   fromCEnum x = fromIntegral (fromEnum x)
   toCEnum x   = toEnum (fromIntegral x)

-- | Device local memory type
data DeviceLocalMemType
   = CL_LOCAL
   | CL_GLOBAL
   deriving (Show,Enum)

instance CEnum DeviceLocalMemType where
   fromCEnum x = fromIntegral (fromEnum x + 1)
   toCEnum x   = toEnum (fromIntegral x - 1)

-- | Command queue property
data CommandQueueProperty
   = CL_QUEUE_OUT_OF_ORDER -- ^ Replace looong CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE
   | CL_QUEUE_PROFILING    -- ^ Replace CL_QUEUE_PROFILING_ENABLE
   deriving (Show, Bounded, Eq, Ord, Enum, CBitSet)

-- | Command queue properties
type CommandQueueProperties = BitSet Word64 CommandQueueProperty

-- | Return the required size to return a device info
getDeviceInfoRetSize :: DeviceInfo -> Device -> CLRet CSize
getDeviceInfoRetSize infoid dev =
   alloca $ \(dat :: Ptr CSize) -> whenSuccess 
      (rawClGetDeviceInfo (cllib dev) (unwrap dev) (fromCEnum infoid) 0 nullPtr dat)
      (peek dat)

-- | Return a string device info
getDeviceInfoString :: DeviceInfo -> Device -> CLRet String
getDeviceInfoString infoid dev =
   getDeviceInfoRetSize infoid dev >>= \case
      Left err   -> return (Left err)
      Right size ->
         allocaBytes (fromIntegral size) $ \dat -> whenSuccess 
            (rawClGetDeviceInfo (cllib dev) (unwrap dev) (fromCEnum infoid) size (castPtr dat) nullPtr)
            (peekCString dat)
         

-- | Return a boolean device info
getDeviceInfoBool :: DeviceInfo -> Device -> CLRet Bool
getDeviceInfoBool infoid dev = do
   let size = fromIntegral $ sizeOf (fromBool False)
   alloca $ \(dat :: Ptr CLbool) -> whenSuccess 
      (rawClGetDeviceInfo (cllib dev) (unwrap dev) (fromCEnum infoid) size (castPtr dat) nullPtr)
      (fromCLBool <$> peek dat)

-- | Return a unsigned long device info
getDeviceInfoWord64 :: DeviceInfo -> Device -> CLRet Word64
getDeviceInfoWord64 infoid dev = do
   let size = fromIntegral $ sizeOf (0 :: Word64)
   alloca $ \(dat :: Ptr Word64) -> whenSuccess 
      (rawClGetDeviceInfo (cllib dev) (unwrap dev) (fromCEnum infoid) size (castPtr dat) nullPtr)
      (peek dat)


-- | Return OpenCL device name
getDeviceName :: Device -> CLRet String
getDeviceName = getDeviceInfoString CL_DEVICE_NAME

-- | Return OpenCL device name (throw an exception on error)
getDeviceName' :: Device -> IO String
getDeviceName' = fmap toException . getDeviceName

-- | Return OpenCL device name
getDeviceVendor :: Device -> CLRet String
getDeviceVendor = getDeviceInfoString CL_DEVICE_VENDOR

-- | Return OpenCL device name (throw an exception on error)
getDeviceVendor' :: Device -> IO String
getDeviceVendor' = fmap toException . getDeviceVendor

-- | Return OpenCL device type
getDeviceType :: Device -> CLRet DeviceTypeSet
getDeviceType dev = fmap BitSet.fromBits <$> getDeviceInfoWord64 CL_DEVICE_TYPE dev

-- | Return OpenCL device type (throw an exception on error)
getDeviceType' :: Device -> IO DeviceTypeSet
getDeviceType' = fmap toException . getDeviceType

-- | Indicate if the device is little endian
isDeviceLittleEndian :: Device -> CLRet Bool
isDeviceLittleEndian = getDeviceInfoBool CL_DEVICE_ENDIAN_LITTLE

-- | Indicate if the device is little endian (throw an exception on error)
isDeviceLittleEndian' :: Device -> IO Bool
isDeviceLittleEndian' = fmap toException . isDeviceLittleEndian

-- | Size of global device memory in bytes
getDeviceGlobalMemSize :: Device -> CLRet Word64
getDeviceGlobalMemSize = getDeviceInfoWord64 CL_DEVICE_GLOBAL_MEM_SIZE

-- | Size of global device memory in bytes (throw an exception on error)
getDeviceGlobalMemSize' :: Device -> IO Word64
getDeviceGlobalMemSize' = fmap toException . getDeviceGlobalMemSize

-- | Get endianness of an OpenCL device
getDeviceEndianness :: Device -> IO Endianness
getDeviceEndianness dev = toEndianness <$> isDeviceLittleEndian' dev
   where
      toEndianness True = LittleEndian
      toEndianness False = BigEndian

-- | Return OpenCL device queue properties
getDeviceQueueProperties :: Device -> CLRet CommandQueueProperties
getDeviceQueueProperties dev = fmap BitSet.fromBits <$> getDeviceInfoWord64 CL_DEVICE_QUEUE_PROPERTIES dev

-- | Return OpenCL device queue properties (throw an exception on error)
getDeviceQueueProperties' :: Device -> IO CommandQueueProperties
getDeviceQueueProperties' = fmap toException . getDeviceQueueProperties


