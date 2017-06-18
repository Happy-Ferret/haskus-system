{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Frame buffer management
module Haskus.System.Linux.Graphics.FrameBuffer
   ( Surface(..)
   , FrameBuffer(..)
   , addFrameBuffer
   , removeFrameBuffer
   , dirtyFrameBuffer
   , PageFlipFlag (..)
   , PageFlipFlags
   , DirtyAnnotation (..)
   , Clip (..)
   )
where

import Haskus.System.Linux.ErrorCode
import Haskus.System.Linux.Handle
import Haskus.System.Linux.Graphics.PixelFormat
import Haskus.System.Linux.Graphics.IDs
import Haskus.System.Linux.Internals.Graphics
import Haskus.Format.Binary.Vector as Vector
import Haskus.Format.Binary.Word
import Haskus.Format.Binary.Ptr
import Haskus.Format.Binary.Storable
import Haskus.Utils.Tuple
import Haskus.Utils.Flow
import Haskus.Utils.List (zip4)

-- | Surface
data Surface = Surface
   { surfaceHandle    :: Word32 -- ^ Handle of the surface
   , surfacePitch     :: Word32 -- ^ Pitch of the surface
   , surfaceOffset    :: Word32 -- ^ Offset of the surface
   , surfaceModifiers :: Word64 -- ^ Modifiers for the surface
   } deriving (Show)

-- | Frame buffer
data FrameBuffer = FrameBuffer
   { fbID          :: FrameBufferID    -- ^ Frame buffer identifier
   , fbWidth       :: Word32           -- ^ Frame buffer width
   , fbHeight      :: Word32           -- ^ Frame buffer height
   , fbPixelFormat :: PixelFormat      -- ^ Pixel format
   , fbFlags       :: FrameBufferFlags -- ^ Flags
   , fbSurfaces    :: [Surface]        -- ^ Data sources (up to four)
   } deriving (Show)

fromFrameBuffer :: FrameBuffer -> StructFrameBufferCommand
fromFrameBuffer FrameBuffer{..} = s
   where
      FrameBufferID fbid = fbID
      g :: (Num a,Storable a) => (Surface -> a) -> Vector 4 a
      g f = Vector.fromFilledList 0 (fmap f fbSurfaces)
      s   = StructFrameBufferCommand fbid
               fbWidth fbHeight fbPixelFormat fbFlags
               (g surfaceHandle) (g surfacePitch)
               (g surfaceOffset) (g surfaceModifiers)

toFrameBuffer :: StructFrameBufferCommand -> FrameBuffer
toFrameBuffer StructFrameBufferCommand{..} = s
   where
      bufs = uncurry4 Surface <$> zip4
               (Vector.toList fc2Handles)
               (Vector.toList fc2Pitches)
               (Vector.toList fc2Offsets)
               (Vector.toList fc2Modifiers)
      s = FrameBuffer (FrameBufferID fc2FbId)
            fc2Width fc2Height fc2PixelFormat fc2Flags bufs


-- | Create a framebuffer
addFrameBuffer :: MonadIO m => Handle -> Word32 -> Word32 -> PixelFormat -> FrameBufferFlags -> [Surface] -> Flow m '[FrameBuffer,ErrorCode]
addFrameBuffer hdl width height fmt flags buffers = do
   
   let s = FrameBuffer (FrameBufferID 0) width height
               fmt flags buffers

   liftIO (ioctlAddFrameBuffer (fromFrameBuffer s) hdl)
      >.-.> toFrameBuffer

-- | Release a frame buffer
removeFrameBuffer :: MonadIO m => Handle -> FrameBuffer -> Flow m '[(),ErrorCode]
removeFrameBuffer hdl fb = do
   let FrameBufferID fbid = fbID fb
   liftIO (ioctlRemoveFrameBuffer fbid hdl)
      >.-.> const ()


-- | Indicate dirty parts of a framebuffer
dirtyFrameBuffer :: MonadInIO m => Handle -> FrameBuffer -> DirtyAnnotation -> Flow m '[(),ErrorCode]
dirtyFrameBuffer hdl fb mode = do
   let
      (color,flags,clips) = case mode of
         Dirty     cs   -> (0,0,cs)
         DirtyCopy cs   -> (0,1, concatMap (\(a,b) -> [a,b]) cs)
         DirtyFill c cs -> (c,2,cs)
      FrameBufferID fbid = fbID fb

   withArray clips $ \clipPtr -> do
      let s = StructFrameBufferDirty
               { fdFbId     = fbid
               , fdFlags    = flags
               , fdColor    = color
               , fdNumClips = fromIntegral (length clips)
               , fdClipsPtr = fromIntegral (ptrToWordPtr clipPtr)
               }
      liftIO (ioctlDirtyFrameBuffer s hdl) >.-.> const ()


