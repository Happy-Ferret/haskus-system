{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DataKinds #-}

-- | Generic buffer management
--
-- Generic buffers are unaccelerated buffers that can be used with all devices
-- that support them with the same API (contrary to accelerated buffers)
--
-- Generic buffers are called "dumb buffers" in original terminology
--
module Haskus.System.Linux.Graphics.GenericBuffer
   ( GenericBuffer
   , GenericBufferMap
   , createGenericBuffer
   , destroyGenericBuffer
   , mapGenericBuffer
   )
where

import Haskus.System.Linux.ErrorCode
import Haskus.System.Linux.Handle
import Haskus.System.Linux.Internals.Graphics
import Haskus.Utils.Flow
import Haskus.Format.Binary.Word

type GenericBuffer = StructCreateDumb
type GenericBufferMap = StructMapDumb

-- | Create a generic buffer
createGenericBuffer :: MonadIO m => Handle -> Word32 -> Word32 -> Word32 -> Word32 -> Flow m '[GenericBuffer,ErrorCode]
createGenericBuffer hdl width height bpp flags = do
   let s = StructCreateDumb height width bpp flags 0 0 0
   liftIO (ioctlCreateGenericBuffer s hdl)

-- | Destroy a generic buffer
destroyGenericBuffer :: MonadIO m => Handle -> GenericBuffer -> Flow m '[(),ErrorCode]
destroyGenericBuffer hdl buffer = do
   let s = StructDestroyDumb (cdHandle buffer)
   liftIO (ioctlDestroyGenericBuffer s hdl) >.-.> const ()

-- | Map a Generic buffer
mapGenericBuffer :: MonadIO m => Handle -> GenericBuffer -> Flow m '[GenericBufferMap,ErrorCode]
mapGenericBuffer hdl buffer = do
   let s = StructMapDumb (cdHandle buffer) 0 0
   liftIO (ioctlMapGenericBuffer s hdl)
