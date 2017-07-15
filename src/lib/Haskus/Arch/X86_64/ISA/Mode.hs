-- | X86 architectures support several operating modes.
-- This module gives information for each mode
module Haskus.Arch.X86_64.ISA.Mode 
   ( X86Mode (..)
   , LongSubMode (..)
   , LegacySubMode (..)
   , X86Extension(..)
   , allExtensions
   , ModeInfo (..)
   , getModeInfo
   , is64bitMode
   , is32bitMode
   , isLongMode
   -- * Execution mode
   , ExecMode (..)
   , hasExtension
   )
where

import Haskus.Arch.X86_64.ISA.Size


-- | X86 and X86-64 operating mode
data X86Mode
   = LongMode LongSubMode     -- ^ x86-64 long mode
   | LegacyMode LegacySubMode -- ^ x86-32 mode
   deriving (Show,Eq)

-- | Sub-mode for x86-64
data LongSubMode
   = Long64bitMode 
   | CompatibilityMode 
   deriving (Show,Eq)

-- | Sub-mode for x86-32 (legacy)
data LegacySubMode
   = ProtectedMode 
   | Virtual8086Mode 
   | RealMode 
   deriving (Show,Eq)

data X86Extension
   = VEX             -- ^ VEX encoded instruction support
   | XOP             -- ^ XOP encoded instruction support
   | ADX             -- ^ ADX extension
   | MMX             -- ^ MMX
   | AVX             -- ^ AVX extension
   | AVX2            -- ^ AVX2 extension
   | SSE             -- ^ SSE extension
   | SSE2            -- ^ SSE2 extension
   | SSE3            -- ^ SSE3 extension
   | SSSE3           -- ^ SSSE3 extension
   | SSE4_1          -- ^ SSE4.1 extension
   | SSE4_2          -- ^ SSE4.2 extension
   | AES             -- ^ AES extension
   | BMI1            -- ^ BMI1 extension
   | BMI2            -- ^ BMI2 extension
   | SMAP            -- ^ Supervisor Mode Access Prevention (SMAP)
   | CLFLUSH         -- ^ CLFLUSH instruction
   | CX8             -- ^ CMPXCHG8B instruction
   | FPU             -- ^ x87 instructions
   | CMOV            -- ^ CMOVs instructions (and FCMOVcc if FPU is set too)
   | INVPCID         -- ^ Invalid process-context identifier (INVPCID) extension
   | MONITOR         -- ^ MONITOR/MWAIT
   | PCLMULQDQ       -- ^ PCLMULQDQ instruction
   | PRFCHW          -- ^ PREFETCHW instruction
   | PREFETCHWT1     -- ^ PREFETCHWT1 instruction
   | FSGSBASE        -- ^ RDFSBASE instruction
   | OSPKE           -- ^ RDPKRU instruction
   | RDRAND          -- ^ RDRAND instruction
   | RDSEDD          -- ^ RDSEED instruction
   | LSAHF           -- ^ LAHF/SAHF instruction in 64-bit mode
   | F16C            -- ^ VCVTPH2PS/VCVTPS2PH instructions
   | FMA             -- ^ Fused multiply-add extension
   | RTM             -- ^ Transactional memory
   | AMD3DNow        -- ^ AMD 3DNow! instructions
   deriving (Show,Eq,Enum,Bounded)

-- | All the X86 extensions
allExtensions :: [X86Extension]
allExtensions = [minBound .. maxBound]

-- | IP-relative addressing support
data RelativeAddressing
   = FullRelativeAddressing      -- ^ Supported by all instructions
   | ControlRelativeAddressing   -- ^ Supported by control instructions
   deriving (Show,Eq)

-- | Information on a given mode
data ModeInfo = ModeInfo
   { relativeAddressing :: RelativeAddressing -- ^ IP-relative addressing support
   }

-- | Return information for the selected mode
getModeInfo :: X86Mode -> ModeInfo
getModeInfo mode = case mode of

   LongMode Long64bitMode     -> ModeInfo {
      relativeAddressing         = FullRelativeAddressing
   }

   LongMode CompatibilityMode -> ModeInfo {
      relativeAddressing         = ControlRelativeAddressing
   }

   LegacyMode ProtectedMode   -> ModeInfo {
      relativeAddressing         = ControlRelativeAddressing
   }

   LegacyMode Virtual8086Mode -> ModeInfo {
      relativeAddressing         = ControlRelativeAddressing
   }

   LegacyMode RealMode        -> ModeInfo {
      relativeAddressing         = ControlRelativeAddressing
   }

-- | Indicate if it is 64 bit mode
is64bitMode :: X86Mode -> Bool
is64bitMode (LongMode Long64bitMode) = True
is64bitMode _                        = False

-- | Indicate if it is 32 bit mode
is32bitMode :: X86Mode -> Bool
is32bitMode (LongMode CompatibilityMode) = True
is32bitMode (LegacyMode ProtectedMode)   = True
is32bitMode _                            = False

-- | Indicate if it is Long mode
isLongMode :: X86Mode -> Bool
isLongMode (LongMode _) = True
isLongMode _            = False


-- | Execution mode
data ExecMode = ExecMode
   { x86Mode            :: X86Mode        -- ^ x86 mode
   , defaultAddressSize :: AddressSize    -- ^ Default address size (used in protected/compat mode)
   , defaultOperandSize :: OperandSize    -- ^ Default operand size (used in protected/compat mode)
   , extensions         :: [X86Extension] -- ^ Enabled extensions
   }

-- | Indicate if an extension is enabled
hasExtension :: ExecMode -> X86Extension -> Bool
hasExtension mode ext = ext `elem` extensions mode


