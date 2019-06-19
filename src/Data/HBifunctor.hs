{-# LANGUAGE DeriveDataTypeable   #-}
{-# LANGUAGE DeriveFoldable       #-}
{-# LANGUAGE DeriveFunctor        #-}
{-# LANGUAGE DeriveGeneric        #-}
{-# LANGUAGE DeriveTraversable    #-}
{-# LANGUAGE DerivingVia          #-}
{-# LANGUAGE KindSignatures       #-}
{-# LANGUAGE LambdaCase           #-}
{-# LANGUAGE RankNTypes           #-}
{-# LANGUAGE StandaloneDeriving   #-}
{-# LANGUAGE TemplateHaskell      #-}
{-# LANGUAGE TypeFamilies         #-}
{-# LANGUAGE TypeInType           #-}
{-# LANGUAGE TypeOperators        #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ViewPatterns         #-}

-- |
-- Module      : Data.HBifunctor
-- Copyright   : (c) Justin Le 2019
-- License     : BSD3
--
-- Maintainer  : justin@jle.im
-- Stability   : experimental
-- Portability : non-portable
--
-- This module provides an abstraction for "two-argument functor
-- combinators", 'HBifunctor', as well as some useful combinators.
module Data.HBifunctor (
    HBifunctor(..)
  , WrappedHBifunctor(..)
  , overHBifunctor
  -- * Simple Instances
  , LeftF(..)
  , RightF(..)
  ) where

import           Control.Natural.IsoF
import           Data.Biapplicative
import           Data.Bifunctor.TH
import           Data.Constraint.Trivial
import           Data.Data
import           Data.Deriving
import           Data.HFunctor
import           Data.HFunctor.Internal
import           Data.HFunctor.Interpret
import           GHC.Generics

-- | Lift two isomorphisms on each side of a bifunctor to become an
-- isomorphism between the two bifunctor applications.
--
-- Basically, if @f@ and @f'@ are isomorphic, and @g@ and @g'@ are
-- isomorphic, then @t f g@ is isomorphic to @t f' g'@.
overHBifunctor
    :: HBifunctor t
    => (f <~> f')
    -> (g <~> g')
    -> t f g <~> t f' g'
overHBifunctor f g =
        isoF (hbimap (viewF   f) (viewF   g))
             (hbimap (reviewF f) (reviewF g))

-- | An 'HBifunctor' that ignores its second input.  Like
-- a 'GHC.Generics.:+:' with no 'GHC.Generics.R1'/right branch.
--
-- This is 'Data.Bifunctors.Joker.Joker' from "Data.Bifunctors.Joker", but
-- given a more sensible name for its purpose.
newtype LeftF f g a = LeftF { runLeftF :: f a }
  deriving (Show, Read, Eq, Ord, Functor, Foldable, Traversable, Typeable, Generic, Data)

deriveShow1 ''LeftF
deriveRead1 ''LeftF
deriveEq1 ''LeftF
deriveOrd1 ''LeftF
deriveBifunctor ''LeftF
deriveBifoldable ''LeftF
deriveBitraversable ''LeftF

instance Applicative f => Biapplicative (LeftF f) where
    bipure _ y = LeftF (pure y)
    LeftF x <<*>> LeftF y = LeftF (x <*> y)

instance HBifunctor LeftF where
    hbimap f _ (LeftF x) = LeftF (f x)

deriving via (WrappedHBifunctor LeftF f)
    instance HFunctor (LeftF f)

-- | An 'HBifunctor' that ignores its first input.  Like
-- a 'GHC.Generics.:+:' with no 'GHC.Generics.L1'/left branch.
--
-- In its polykinded form (on @f@), it is essentially a higher-order
-- version of 'Data.Tagged.Tagged'.
newtype RightF f g a = RightF { runRightF :: g a }
  deriving (Show, Read, Eq, Ord, Functor, Foldable, Traversable, Typeable, Generic, Data)

deriveShow1 ''RightF
deriveRead1 ''RightF
deriveEq1 ''RightF
deriveOrd1 ''RightF

instance HBifunctor RightF where
    hbimap _ g (RightF x) = RightF (g x)

deriving via (WrappedHBifunctor RightF f)
    instance HFunctor (RightF f)

instance HFunctor (RightF f) where
    hmap f (RightF x) = RightF (f x)

instance Inject (RightF f) where
    inject = RightF

instance HBind (RightF f) where
    hbind f (RightF x) = f x

instance Interpret (RightF f) where
    type C (RightF f) = Unconstrained
    retract (RightF x) = x
    interpret f (RightF x) = f x