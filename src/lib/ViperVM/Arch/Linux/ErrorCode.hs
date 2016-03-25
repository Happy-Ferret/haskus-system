{-# LANGUAGE LambdaCase #-}

-- | Management of returned values from syscalls
module ViperVM.Arch.Linux.ErrorCode 
   ( SysRet
   , ErrorCode (..)
   , unhdlErr
   , defaultCheck
   , defaultCheckRet
   , checkReturn
   , toErrorCode
   , onSuccessIO
   , onSuccess
   , onSuccessId
   , onSuccessVoid
   )
where

import Data.Int (Int64)

-- | Syscall return type
type SysRet a = IO (Either ErrorCode a)

-- | Convert an error code into ErrorCode type
toErrorCode :: Int64 -> ErrorCode
toErrorCode = toEnum . fromIntegral . (*(-1))

-- | Use defaultCheck to check for error and return () otherwise
--
-- Similar to LIBC's behavior (return 0 except on error)
defaultCheckRet :: Int64 -> SysRet ()
defaultCheckRet x = case defaultCheck x of
   Nothing  -> return (Right ())
   Just err -> return (Left err)

checkReturn :: Int64 -> SysRet Int64
checkReturn x = case defaultCheck x of
   Nothing  -> return (Right x)
   Just err -> return (Left err)

-- | Apply an IO function to the result of the action if no error occured (use
-- `defaultCheck` to detect an error)
onSuccessIO :: IO Int64 -> (Int64 -> IO a) -> SysRet a
onSuccessIO sc f = do
   ret <- sc
   case defaultCheck ret of
      Just err -> return (Left err)
      Nothing  -> Right <$> f ret

-- | Apply a function to the result of the action if no error occured (use
-- `defaultCheck` to detect an error)
onSuccess :: IO Int64 -> (Int64 -> a) -> SysRet a
onSuccess sc f = do
   ret <- sc
   return $ case defaultCheck ret of
      Just err -> Left err
      Nothing  -> Right (f ret)

-- | Check for error and return the value otherwise
onSuccessId :: IO Int64 -> SysRet Int64
onSuccessId = flip onSuccess id

-- | Check for error and return void
onSuccessVoid :: IO Int64 -> SysRet ()
onSuccessVoid = flip onSuccess (const ())


------------------------------------------------
-- Low-level error codes
------------------------------------------------

-- | Default error checking (if < 0 then error)
defaultCheck :: Int64 -> Maybe ErrorCode
defaultCheck x | x < 0     = Just (toErrorCode x)
               | otherwise = Nothing

-- | Error to call when a syscall returns an unexpected error value
unhdlErr :: String -> ErrorCode -> a
unhdlErr str err =
   error ("Unhandled error "++ show err ++" returned by \""++str++"\". Report this as a ViperVM bug.")


-- | Linux error codes
data ErrorCode
   = EPERM              -- ^ Operation not permitted
   | ENOENT             -- ^ No such file or directory
   | ESRCH              -- ^ No such process
   | EINTR              -- ^ Interrupted system call
   | EIO                -- ^ I/O error 
   | ENXIO              -- ^ No such device or address 
   | E2BIG              -- ^ Argument list too long 
   | ENOEXEC            -- ^ Exec format error 
   | EBADF              -- ^ Bad file number 
   | ECHILD             -- ^ No child processes 
   | EAGAIN             -- ^ Try again 
   | ENOMEM             -- ^ Out of memory 
   | EACCES             -- ^ Permission denied 
   | EFAULT             -- ^ Bad address 
   | ENOTBLK            -- ^ Block device required 
   | EBUSY              -- ^ Device or resource busy 
   | EEXIST             -- ^ File exists 
   | EXDEV              -- ^ Cross-device link 
   | ENODEV             -- ^ No such device 
   | ENOTDIR            -- ^ Not a directory 
   | EISDIR             -- ^ Is a directory 
   | EINVAL             -- ^ Invalid argument 
   | ENFILE             -- ^ File table overflow 
   | EMFILE             -- ^ Too many open files 
   | ENOTTY             -- ^ Not a typewriter 
   | ETXTBSY            -- ^ Text file busy 
   | EFBIG              -- ^ File too large 
   | ENOSPC             -- ^ No space left on device 
   | ESPIPE             -- ^ Illegal seek 
   | EROFS              -- ^ Read-only file system 
   | EMLINK             -- ^ Too many links 
   | EPIPE              -- ^ Broken pipe 
   | EDOM               -- ^ Math argument out of domain of func 
   | ERANGE             -- ^ Math result not representable 

   | EDEADLK            -- ^ Resource deadlock would occur 
   | ENAMETOOLONG       -- ^ File name too long 
   | ENOLCK             -- ^ No record locks available 
   | ENOSYS             -- ^ Function not implemented 
   | ENOTEMPTY          -- ^ Directory not empty 
   | ELOOP              -- ^ Too many symbolic links encountered 
   | ENOMSG             -- ^ No message of desired type 
   | EIDRM              -- ^ Identifier removed 
   | ECHRNG             -- ^ Channel number out of range 
   | EL2NSYNC           -- ^ Level 2 not synchronized 
   | EL3HLT             -- ^ Level 3 halted 
   | EL3RST             -- ^ Level 3 reset 
   | ELNRNG             -- ^ Link number out of range 
   | EUNATCH            -- ^ Protocol driver not attached 
   | ENOCSI             -- ^ No CSI structure available 
   | EL2HLT             -- ^ Level 2 halted 
   | EBADE              -- ^ Invalid exchange 
   | EBADR              -- ^ Invalid request descriptor 
   | EXFULL             -- ^ Exchange full 
   | ENOANO             -- ^ No anode 
   | EBADRQC            -- ^ Invalid request code 
   | EBADSLT            -- ^ Invalid slot 
   | EBFONT             -- ^ Bad font file format 
   | ENOSTR             -- ^ Device not a stream 
   | ENODATA            -- ^ No data available 
   | ETIME              -- ^ Timer expired 
   | ENOSR              -- ^ Out of streams resources 
   | ENONET             -- ^ Machine is not on the network 
   | ENOPKG             -- ^ Package not installed 
   | EREMOTE            -- ^ Object is remote 
   | ENOLINK            -- ^ Link has been severed 
   | EADV               -- ^ Advertise error 
   | ESRMNT             -- ^ Srmount error 
   | ECOMM              -- ^ Communication error on send 
   | EPROTO             -- ^ Protocol error 
   | EMULTIHOP          -- ^ Multihop attempted 
   | EDOTDOT            -- ^ RFS specific error 
   | EBADMSG            -- ^ Not a data message 
   | EOVERFLOW          -- ^ Value too large for defined data type 
   | ENOTUNIQ           -- ^ Name not unique on network 
   | EBADFD             -- ^ File descriptor in bad state 
   | EREMCHG            -- ^ Remote address changed 
   | ELIBACC            -- ^ Can not access a needed shared library 
   | ELIBBAD            -- ^ Accessing a corrupted shared library 
   | ELIBSCN            -- ^ .lib section in a.out corrupted 
   | ELIBMAX            -- ^ Attempting to link in too many shared libraries 
   | ELIBEXEC           -- ^ Cannot exec a shared library directly 
   | EILSEQ             -- ^ Illegal byte sequence 
   | ERESTART           -- ^ Interrupted system call should be restarted 
   | ESTRPIPE           -- ^ Streams pipe error 
   | EUSERS             -- ^ Too many users 
   | ENOTSOCK           -- ^ Socket operation on non-socket 
   | EDESTADDRREQ       -- ^ Destination address required 
   | EMSGSIZE           -- ^ Message too long 
   | EPROTOTYPE         -- ^ Protocol wrong type for socket 
   | ENOPROTOOPT        -- ^ Protocol not available 
   | EPROTONOSUPPORT    -- ^ Protocol not supported 
   | ESOCKTNOSUPPORT    -- ^ Socket type not supported 
   | EOPNOTSUPP         -- ^ Operation not supported on transport endpoint 
   | EPFNOSUPPORT       -- ^ Protocol family not supported 
   | EAFNOSUPPORT       -- ^ Address family not supported by protocol 
   | EADDRINUSE         -- ^ Address already in use 
   | EADDRNOTAVAIL      -- ^ Cannot assign requested address 
   | ENETDOWN           -- ^ Network is down 
   | ENETUNREACH        -- ^ Network is unreachable 
   | ENETRESET          -- ^ Network dropped connection because of reset 
   | ECONNABORTED       -- ^ Software caused connection abort 
   | ECONNRESET         -- ^ Connection reset by peer 
   | ENOBUFS            -- ^ No buffer space available 
   | EISCONN            -- ^ Transport endpoint is already connected 
   | ENOTCONN           -- ^ Transport endpoint is not connected 
   | ESHUTDOWN          -- ^ Cannot send after transport endpoint shutdown 
   | ETOOMANYREFS       -- ^ Too many references: cannot splice 
   | ETIMEDOUT          -- ^ Connection timed out 
   | ECONNREFUSED       -- ^ Connection refused 
   | EHOSTDOWN          -- ^ Host is down 
   | EHOSTUNREACH       -- ^ No route to host 
   | EALREADY           -- ^ Operation already in progress 
   | EINPROGRESS        -- ^ Operation now in progress 
   | ESTALE             -- ^ Stale file handle 
   | EUCLEAN            -- ^ Structure needs cleaning 
   | ENOTNAM            -- ^ Not a XENIX named type file 
   | ENAVAIL            -- ^ No XENIX semaphores available 
   | EISNAM             -- ^ Is a named type file 
   | EREMOTEIO          -- ^ Remote I/O error 
   | EDQUOT             -- ^ Quota exceeded 
   | ENOMEDIUM          -- ^ No medium found 
   | EMEDIUMTYPE        -- ^ Wrong medium type 
   | ECANCELED          -- ^ Operation Canceled 
   | ENOKEY             -- ^ Required key not available 
   | EKEYEXPIRED        -- ^ Key has expired 
   | EKEYREVOKED        -- ^ Key has been revoked 
   | EKEYREJECTED       -- ^ Key was rejected by service 
   | EOWNERDEAD         -- ^ Owner died 
   | ENOTRECOVERABLE    -- ^ State not recoverable 
   | ERFKILL            -- ^ Operation not possible due to RF-kill 
   | EHWPOISON          -- ^ Memory page has hardware error
   deriving (Show)

instance Enum ErrorCode where
   fromEnum x = case x of
      EPERM   -> 1 
      ENOENT  -> 2 
      ESRCH   -> 3 
      EINTR   -> 4 
      EIO     -> 5 
      ENXIO   -> 6 
      E2BIG   -> 7 
      ENOEXEC -> 8 
      EBADF   -> 9 
      ECHILD  -> 10
      EAGAIN  -> 11
      ENOMEM  -> 12
      EACCES  -> 13
      EFAULT  -> 14
      ENOTBLK -> 15
      EBUSY   -> 16
      EEXIST  -> 17
      EXDEV   -> 18
      ENODEV  -> 19
      ENOTDIR -> 20
      EISDIR  -> 21
      EINVAL  -> 22
      ENFILE  -> 23
      EMFILE  -> 24
      ENOTTY  -> 25
      ETXTBSY -> 26
      EFBIG   -> 27
      ENOSPC  -> 28
      ESPIPE  -> 29
      EROFS   -> 30
      EMLINK  -> 31
      EPIPE   -> 32
      EDOM    -> 33
      ERANGE  -> 34

      EDEADLK            -> 35 
      ENAMETOOLONG       -> 36 
      ENOLCK             -> 37 
      ENOSYS             -> 38 
      ENOTEMPTY          -> 39 
      ELOOP              -> 40 
      ENOMSG             -> 42 
      EIDRM              -> 43 
      ECHRNG             -> 44 
      EL2NSYNC           -> 45 
      EL3HLT             -> 46 
      EL3RST             -> 47 
      ELNRNG             -> 48 
      EUNATCH            -> 49 
      ENOCSI             -> 50 
      EL2HLT             -> 51 
      EBADE              -> 52 
      EBADR              -> 53 
      EXFULL             -> 54 
      ENOANO             -> 55 
      EBADRQC            -> 56 
      EBADSLT            -> 57 
      EBFONT             -> 59 
      ENOSTR             -> 60 
      ENODATA            -> 61 
      ETIME              -> 62 
      ENOSR              -> 63 
      ENONET             -> 64 
      ENOPKG             -> 65 
      EREMOTE            -> 66 
      ENOLINK            -> 67 
      EADV               -> 68 
      ESRMNT             -> 69 
      ECOMM              -> 70 
      EPROTO             -> 71 
      EMULTIHOP          -> 72 
      EDOTDOT            -> 73 
      EBADMSG            -> 74 
      EOVERFLOW          -> 75 
      ENOTUNIQ           -> 76 
      EBADFD             -> 77 
      EREMCHG            -> 78 
      ELIBACC            -> 79 
      ELIBBAD            -> 80 
      ELIBSCN            -> 81 
      ELIBMAX            -> 82 
      ELIBEXEC           -> 83 
      EILSEQ             -> 84 
      ERESTART           -> 85 
      ESTRPIPE           -> 86 
      EUSERS             -> 87 
      ENOTSOCK           -> 88 
      EDESTADDRREQ       -> 89 
      EMSGSIZE           -> 90 
      EPROTOTYPE         -> 91 
      ENOPROTOOPT        -> 92 
      EPROTONOSUPPORT    -> 93 
      ESOCKTNOSUPPORT    -> 94 
      EOPNOTSUPP         -> 95 
      EPFNOSUPPORT       -> 96 
      EAFNOSUPPORT       -> 97 
      EADDRINUSE         -> 98 
      EADDRNOTAVAIL      -> 99 
      ENETDOWN           -> 100
      ENETUNREACH        -> 101
      ENETRESET          -> 102
      ECONNABORTED       -> 103
      ECONNRESET         -> 104
      ENOBUFS            -> 105
      EISCONN            -> 106
      ENOTCONN           -> 107
      ESHUTDOWN          -> 108
      ETOOMANYREFS       -> 109
      ETIMEDOUT          -> 110
      ECONNREFUSED       -> 111
      EHOSTDOWN          -> 112
      EHOSTUNREACH       -> 113
      EALREADY           -> 114
      EINPROGRESS        -> 115
      ESTALE             -> 116
      EUCLEAN            -> 117
      ENOTNAM            -> 118
      ENAVAIL            -> 119
      EISNAM             -> 120
      EREMOTEIO          -> 121
      EDQUOT             -> 122
      ENOMEDIUM          -> 123
      EMEDIUMTYPE        -> 124
      ECANCELED          -> 125
      ENOKEY             -> 126
      EKEYEXPIRED        -> 127
      EKEYREVOKED        -> 128
      EKEYREJECTED       -> 129
      EOWNERDEAD         -> 130
      ENOTRECOVERABLE    -> 131
      ERFKILL            -> 132
      EHWPOISON          -> 133

   toEnum x = case x of
      1   -> EPERM
      2   -> ENOENT
      3   -> ESRCH
      4   -> EINTR
      5   -> EIO
      6   -> ENXIO
      7   -> E2BIG
      8   -> ENOEXEC
      9   -> EBADF
      10  -> ECHILD
      11  -> EAGAIN
      12  -> ENOMEM
      13  -> EACCES
      14  -> EFAULT
      15  -> ENOTBLK
      16  -> EBUSY
      17  -> EEXIST
      18  -> EXDEV
      19  -> ENODEV
      20  -> ENOTDIR
      21  -> EISDIR
      22  -> EINVAL
      23  -> ENFILE
      24  -> EMFILE
      25  -> ENOTTY
      26  -> ETXTBSY
      27  -> EFBIG
      28  -> ENOSPC
      29  -> ESPIPE
      30  -> EROFS
      31  -> EMLINK
      32  -> EPIPE
      33  -> EDOM
      34  -> ERANGE
      
      35  -> EDEADLK
      36  -> ENAMETOOLONG
      37  -> ENOLCK
      38  -> ENOSYS
      39  -> ENOTEMPTY
      40  -> ELOOP
      42  -> ENOMSG
      43  -> EIDRM
      44  -> ECHRNG
      45  -> EL2NSYNC
      46  -> EL3HLT
      47  -> EL3RST
      48  -> ELNRNG
      49  -> EUNATCH
      50  -> ENOCSI
      51  -> EL2HLT
      52  -> EBADE
      53  -> EBADR
      54  -> EXFULL
      55  -> ENOANO
      56  -> EBADRQC
      57  -> EBADSLT
      59  -> EBFONT
      60  -> ENOSTR
      61  -> ENODATA
      62  -> ETIME
      63  -> ENOSR
      64  -> ENONET
      65  -> ENOPKG
      66  -> EREMOTE
      67  -> ENOLINK
      68  -> EADV
      69  -> ESRMNT
      70  -> ECOMM
      71  -> EPROTO
      72  -> EMULTIHOP
      73  -> EDOTDOT
      74  -> EBADMSG
      75  -> EOVERFLOW
      76  -> ENOTUNIQ
      77  -> EBADFD
      78  -> EREMCHG
      79  -> ELIBACC
      80  -> ELIBBAD
      81  -> ELIBSCN
      82  -> ELIBMAX
      83  -> ELIBEXEC
      84  -> EILSEQ
      85  -> ERESTART
      86  -> ESTRPIPE
      87  -> EUSERS
      88  -> ENOTSOCK
      89  -> EDESTADDRREQ
      90  -> EMSGSIZE
      91  -> EPROTOTYPE
      92  -> ENOPROTOOPT
      93  -> EPROTONOSUPPORT
      94  -> ESOCKTNOSUPPORT
      95  -> EOPNOTSUPP
      96  -> EPFNOSUPPORT
      97  -> EAFNOSUPPORT
      98  -> EADDRINUSE
      99  -> EADDRNOTAVAIL
      100 -> ENETDOWN
      101 -> ENETUNREACH
      102 -> ENETRESET
      103 -> ECONNABORTED
      104 -> ECONNRESET
      105 -> ENOBUFS
      106 -> EISCONN
      107 -> ENOTCONN
      108 -> ESHUTDOWN
      109 -> ETOOMANYREFS
      110 -> ETIMEDOUT
      111 -> ECONNREFUSED
      112 -> EHOSTDOWN
      113 -> EHOSTUNREACH
      114 -> EALREADY
      115 -> EINPROGRESS
      116 -> ESTALE
      117 -> EUCLEAN
      118 -> ENOTNAM
      119 -> ENAVAIL
      120 -> EISNAM
      121 -> EREMOTEIO
      122 -> EDQUOT
      123 -> ENOMEDIUM
      124 -> EMEDIUMTYPE
      125 -> ECANCELED
      126 -> ENOKEY
      127 -> EKEYEXPIRED
      128 -> EKEYREVOKED
      129 -> EKEYREJECTED
      130 -> EOWNERDEAD
      131 -> ENOTRECOVERABLE
      132 -> ERFKILL
      133 -> EHWPOISON

      _   -> error ("Unrecognized syscall error code "++show x++". Report this as a ViperVM bug.")
