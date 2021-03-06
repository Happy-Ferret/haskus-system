{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}

-- | Kernel object handle
--
-- File descriptor in original terminology
module Haskus.System.Linux.Handle
   ( Handle (..)
   , HandleFlag(..)
   , HandleFlags
   , getHandleFlags
   , setHandleFlags
   , InvalidHandle (..)
   , sysFcntl
   )
where

import Haskus.System.Linux.Error
import Haskus.System.Linux.ErrorCode
import Haskus.System.Linux.Syscalls
import Haskus.System.Linux.Internals.Arg
import Haskus.System.Linux.Internals.Handle
import Haskus.System.Linux.Internals.Fcntl
import Haskus.Format.Binary.BitSet as BitSet
import Haskus.Format.Binary.Word
import Haskus.Format.Binary.Enum
import Haskus.Utils.Flow

-- | Fcntl syscall
sysFcntl :: (MonadIO m, Arg a) => Handle -> FcntlCommand -> a -> Flow m '[Int64,ErrorCode]
sysFcntl (Handle fd) cmd arg =
   liftIO (syscall_fcntl fd (fromCEnum cmd) (toArg arg))
      ||> toErrorCode


-- | Get descriptor flags
getHandleFlags :: MonadIO m => Handle -> Flow m '[HandleFlags,InvalidHandle]
getHandleFlags hdl =
   sysFcntl hdl FcntlGetFlags (0 :: Int)
      >.-.> (BitSet.fromBits . fromIntegral)
      >..%~^> \case
         EBADF -> flowSet InvalidHandle
         e     -> unhdlErr "getHandleFlags" e

-- | Set descriptor flags
setHandleFlags :: MonadIO m => Handle -> HandleFlags -> Flow m '[(),InvalidHandle]
setHandleFlags hdl flgs =
   sysFcntl hdl FcntlSetFlags (BitSet.toBits flgs)
      >.-.> const ()
      >%~^> \case
         EBADF -> flowSet InvalidHandle
         e     -> unhdlErr "setHandleFlags" e

-- | Handle flags 
data HandleFlag
   = HandleWriteOnly
   | HandleReadWrite
   | HandleCloseOnExec
   | HandleAppend
   | HandleAsync
   | HandleCreate
   | HandleDirect
   | HandleDirectory
   | HandleExclusive
   | HandleLargeFile
   | HandleWithoutAccessTime
   | HandleNoTTYControl
   | HandleDontFollowSymLinks
   | HandleNonBlocking
   | HandlePath
   | HandleSynchronous
   | HandleTmpFile
   | HandleTruncate
   deriving (Show,Eq,Enum)

-- | Handle flags
type HandleFlags = BitSet Int HandleFlag

instance CBitSet HandleFlag where
   toBitOffset x = case x of
      HandleWriteOnly          -> 0
      HandleReadWrite          -> 1
      HandleCreate             -> 6
      HandleExclusive          -> 7
      HandleNoTTYControl       -> 8
      HandleTruncate           -> 9
      HandleAppend             -> 10
      HandleNonBlocking        -> 11
      HandleSynchronous        -> 12
      HandleAsync              -> 13
      HandleDirect             -> 14
      HandleLargeFile          -> 15
      HandleDirectory          -> 16
      HandleDontFollowSymLinks -> 17
      HandleWithoutAccessTime  -> 18
      HandleCloseOnExec        -> 19
      HandlePath               -> 21
      HandleTmpFile            -> 22

   fromBitOffset x = case x of
      0  -> HandleWriteOnly
      1  -> HandleReadWrite
      6  -> HandleCreate
      7  -> HandleExclusive
      8  -> HandleNoTTYControl
      9  -> HandleTruncate
      10 -> HandleAppend
      11 -> HandleNonBlocking
      12 -> HandleSynchronous
      13 -> HandleAsync
      14 -> HandleDirect
      15 -> HandleLargeFile
      16 -> HandleDirectory
      17 -> HandleDontFollowSymLinks
      18 -> HandleWithoutAccessTime
      19 -> HandleCloseOnExec
      21 -> HandlePath
      22 -> HandleTmpFile
      _  -> error "Unknown handle flag"
