{-# LANGUAGE PatternSynonyms #-}

-- | A region is a set of memory cells in a buffer with an offset.
--
-- Currently we support two region shapes:
--
-- * Shape1D: region without hole (contiguous set of cells)
--
-- * Shape2D: rectangular set of cells (e.g. sub-array), that is with a
-- constant number of padding bytes after each row
module ViperVM.Platform.Memory.Region
   (
   -- * Shapes
     Shape(..)
   , Size
   , Padding
   , RowCount
   , shapeSimplify
   , shapeCover
   , isHomomorphicWith
   -- * Regions
   , Region(..)
   , pattern Region1D
   , pattern Region2D
   , overlapsAny
   , overlaps
   , regionCover1D
   )
where

import Data.Word

-- | Size in bytes
type Size = Word64      
   
-- | Padding (may be changed to a smaller type in the future)
type Padding = Word64

-- | Number of rows
type RowCount = Word64

-- | Shape of a set of memory cells at a given offset
data Shape
   = Shape1D Size                    -- ^ Contiguous set of cells
   | Shape2D RowCount Size Padding   -- ^ Rectangular set of cells
   deriving (Eq,Ord,Show)

-- | Positioned region (i.e. region shape with an offset)
data Region = Region
   { regionOffset :: Word64
   , regionShape  :: Shape
   }

-- | Pattern synonym for region with 1D shape
pattern Region1D off sz = Region off (Shape1D sz)

-- | Pattern synonym for region with 2D shape
pattern Region2D off nrows sz padding = Region off (Shape2D nrows sz padding)


-- | Check if two regions have the same shape (discarding padding)
isHomomorphicWith :: Shape -> Shape -> Bool
isHomomorphicWith r1 r2 = case (shapeSimplify r1, shapeSimplify r2) of
   (Shape1D s1, Shape1D s2)               -> s1 == s2
   (Shape2D idx1 s1 _, Shape2D idx2 s2 _) -> (s1 == s2) && (idx1 == idx2)
   _                                      -> False

-- | Try to simplify the shape (e.g. transform a 2D region into a 1D one)
shapeSimplify :: Shape -> Shape
shapeSimplify (Shape2D idx s 0) = Shape1D (idx*s)
shapeSimplify (Shape2D 1 s _)   = Shape1D s
shapeSimplify r                 = r

-- | Return covering 1D shape
shapeCover :: Shape -> Shape
shapeCover r@(Shape1D {}) = r
shapeCover (Shape2D nrows sz pad) = Shape1D (nrows * (sz+pad))

-- | Return covering 1D region
regionCover1D :: Region -> Region
regionCover1D (Region off shape) = Region off (shapeCover shape)

-- | Retrieve regions that overlap with the given region
overlapsAny :: Region -> [Region] -> [Region]
overlapsAny reg = filter (overlaps reg)

-- | Indicate if two regions overlap (may return false positive)
overlaps :: Region -> Region -> Bool
overlaps (Region1D off1 sz1) (Region1D off2 sz2) = not (left1 >= right2 || left2 >= right1)
   where
      left1 = off1
      left2 = off2
      right1 = off1+sz1
      right2 = off2+sz2

overlaps (Region1D off sz) r2 = overlaps (Region2D off 1 sz 0) r2
overlaps r2 (Region1D off sz) = overlaps r2 (Region2D off 1 sz 0)

overlaps (Region2D off1 rc1 sz1 pad1) (Region2D off2 rc2 sz2 pad2) 
      | sz1+pad1 == sz2+pad2 = not ( left1 >= right2 || left2 >= right1 || top1 >= bottom2 || top2 >= bottom1 )
   where
      width = sz1+pad1
      (top1,left1) = divMod off1 width
      (top2,left2) = divMod off2 width
      right1 = left1 + sz1
      right2 = left2 + sz2
      bottom1 = top1 + rc1
      bottom2 = top2 + rc2

-- FIXME: by default we say that 2 regions Shape2D overlap if they don't have the same padding.
-- Maybe we could improve this if we find a fast algorithm
overlaps _ _ = True