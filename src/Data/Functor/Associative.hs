{-# LANGUAGE AllowAmbiguousTypes        #-}
{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE DefaultSignatures          #-}
{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE DerivingVia                #-}
{-# LANGUAGE EmptyCase                  #-}
{-# LANGUAGE EmptyDataDeriving          #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE FunctionalDependencies     #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE KindSignatures             #-}
{-# LANGUAGE LambdaCase                 #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE PatternSynonyms            #-}
{-# LANGUAGE QuantifiedConstraints      #-}
{-# LANGUAGE RankNTypes                 #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TupleSections              #-}
{-# LANGUAGE TypeApplications           #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE TypeInType                 #-}
{-# LANGUAGE TypeOperators              #-}
{-# LANGUAGE UndecidableInstances       #-}
{-# LANGUAGE ViewPatterns               #-}


module Data.Functor.Associative (
    Associative(..)
  , assoc
  , disassoc
  , Semigroupoidal(..)
  , matchingSF
  , extractT
  , getT
  , collectT
  , (!*!)
  , (!$!)
  , F1(..)
  , unrollingSF
  , rerollSF
  , concatF1
  -- , toF1, fromF1, asF1
  ) where

import           Control.Applicative
import           Control.Applicative.ListF
import           Control.Applicative.Step
import           Control.Monad.Freer.Church
import           Control.Natural
import           Data.Copointed
import           Data.Foldable
import           Data.Functor.Apply.Free
import           Data.Functor.Bind
import           Data.Functor.Day           (Day(..))
import           Data.Functor.HBifunctor
import           Data.Functor.HFunctor.IsoF
import           Data.Functor.Identity
import           Data.Functor.Interpret
import           Data.Functor.Plus
import           Data.Kind
import           Data.List.NonEmpty         (NonEmpty(..))
import           Data.Proxy
import           GHC.Generics hiding        (C)
import qualified Data.Functor.Day           as D

class HBifunctor t => Associative t where
    associative
        :: (Functor f, Functor g, Functor h)
        => t f (t g h) <~> t (t f g) h
    {-# MINIMAL associative #-}

assoc
    :: (Associative t, Functor f, Functor g, Functor h)
    => t f (t g h)
    ~> t (t f g) h
assoc = viewF associative

disassoc
    :: (Associative t, Functor f, Functor g, Functor h)
    => t (t f g) h
    ~> t f (t g h)
disassoc = reviewF associative

data F1 t f a = Done1 (f a)
              | More1 (t f (F1 t f) a)

deriving instance (Show (t f (F1 t f) a), Show (f a)) => Show (F1 t f a)


deriving instance (Functor f, Functor (t f (F1 t f))) => Functor (F1 t f)

-- data LiftT

-- newtype F1' t f a = F1' { runF1' :: t f (Lift (F1' t f)) a }

-- newtype F1Free t f a = F1F
--     { runF1F :: forall g. Functor g => (f ~> g) -> (t f g ~> g) -> g a }

-- f1Free :: Semigroupoidal t => F1 t f ~> F1Free t f
-- f1Free = \case
--     Done1 x  -> F1F $ \d _ -> d x
--     More1 xs -> F1F $ \d m -> m . hright ((\q -> runF1F q d m) . f1Free) $ xs

-- freeF1 :: (Semigroupoidal t, Functor f, Functor (t f (F1 t f))) => F1Free t f ~> F1 t f
-- freeF1 x = runF1F x Done1 More1

class (Associative t, Interpret (SF t)) => Semigroupoidal t where
    type SF t :: (Type -> Type) -> Type -> Type

    -- | If a @'SF' t f@ represents multiple applications of @t f@ to
    -- itself, then we can also "append" two @'SF' t f@s applied to
    -- themselves into one giant @'SF' t f@ containing all of the @t f@s.
    appendSF :: t (SF t f) (SF t f) ~> SF t f
    matchSF  :: Functor f => SF t f ~> f :+: t f (SF t f)

    -- | Prepend an application of @t f@ to the front of a @'SF' t f@.
    consSF :: t f (SF t f) ~> SF t f
    consSF = appendSF . hleft inject

    -- | Embed a direct application of @f@ to itself into a @'SF' t f@.
    toSF :: t f f ~> SF t f
    toSF = appendSF . hbimap inject inject

    -- | A version of 'retract' that works for a 'Tensor'.  It retracts
    -- /both/ @f@s into a single @f@.
    retractS :: C (SF t) f => t f f ~> f
    retractS = retract . toSF

    -- | A version of 'interpret' that works for a 'Tensor'.  It takes two
    -- interpreting functions, and interprets both joined functors one
    -- after the other into @h@.
    interpretS :: C (SF t) h => (f ~> h) -> (g ~> h) -> t f g ~> h
    interpretS f g = retract . toSF . hbimap f g

    {-# MINIMAL appendSF, matchSF #-}

matchingSF :: (Semigroupoidal t, Functor f) => SF t f <~> f :+: t f (SF t f)
matchingSF = isoF matchSF (inject !*! consSF)

unrollingSF :: forall t f. (Semigroupoidal t, Functor f) => SF t f <~> F1 t f
unrollingSF = isoF unrollSF rerollSF

unrollSF :: forall t f. (Semigroupoidal t, Functor f) => SF t f ~> F1 t f
unrollSF = (Done1 !*! More1 . hright unrollSF) . matchSF @t

rerollSF :: Semigroupoidal t => F1 t f ~> SF t f
rerollSF = \case
    Done1 x  -> inject x
    More1 xs -> consSF . hright rerollSF $ xs

concatF1 :: (Semigroupoidal t, Functor f) => F1 t (SF t f) ~> F1 t f
concatF1 = \case
    Done1 x  -> unrollSF x
    More1 xs -> unrollSF . appendSF . hright (rerollSF . concatF1) $ xs

-- | Useful wrapper over 'retractT' to allow you to directly extract an @a@
-- from a @t f f a@, if @f@ is a valid retraction from @t@, and @f@ is an
-- instance of 'Copointed'.
--
-- Useful @f@s include 'Identity' or related newtype wrappers from
-- base:
--
-- @
-- 'extractT'
--     :: ('Monoidal' t, 'C' ('MF' t) 'Identity')
--     => t 'Identity' 'Identity' a
--     -> a
-- @
extractT
    :: (Semigroupoidal t, C (SF t) f, Copointed f)
    => t f f a
    -> a
extractT = copoint . retractS

-- | Useful wrapper over 'interpret' to allow you to directly extract
-- a value @b@ out of the @t f a@, if you can convert @f x@ into @b@.
--
-- Note that depending on the constraints on the interpretation of @t@, you
-- may have extra constraints on @b@.
--
-- *    If @'C' ('MF' t)@ is 'Data.Constraint.Trivial.Unconstrained', there
--      are no constraints on @b@
-- *    If @'C' ('MF' t)@ is 'Apply', @b@ needs to be an instance of 'Semigroup'
-- *    If @'C' ('MF' t)@ is 'Applicative', @b@ needs to be an instance of 'Monoid'
--
-- For some constraints (like 'Monad'), this will not be usable.
--
-- @
-- -- Return the length of either the list, or the Map, depending on which
-- --   one s in the '+'
-- length !*! length
--     :: ([] :+: Map Int) Char
--     -> Int
--
-- -- Return the length of both the list and the map, added together
-- (Sum . length) !*! (Sum . length)
--     :: Day [] (Map Int) Char
--     -> Sum Int
-- @
getT
    :: (Semigroupoidal t, C (SF t) (Const b))
    => (forall x. f x -> b)
    -> (forall x. g x -> b)
    -> t f g a
    -> b
getT f g = getConst . interpretS (Const . f) (Const . g)

-- | Infix alias for 'getT'
(!$!)
    :: (Semigroupoidal t, C (SF t) (Const b))
    => (forall x. f x -> b)
    -> (forall x. g x -> b)
    -> t f g a
    -> b
(!$!) = getT
infixr 5 !$!

-- | Infix alias for 'interpretS'
(!*!)
    :: (Semigroupoidal t, C (SF t) h)
    => (f ~> h)
    -> (g ~> h)
    -> t f g
    ~> h
(!*!) = interpretS
infixr 5 !*!

-- | Useful wrapper over 'getT' to allow you to collect a @b@ from all
-- instances of @f@ and @g@ inside a @t f g a@.
--
-- This will work if @'C' t@ is 'Data.Constraint.Trivial.Unconstrained',
-- 'Apply', or 'Applicative'.
collectT
    :: (Semigroupoidal t, C (SF t) (Const [b]))
    => (forall x. f x -> b)
    -> (forall x. g x -> b)
    -> t f g a
    -> [b]
collectT f g = getConst . interpretS (Const . (:[]) . f) (Const . (:[]) . g)

instance Associative (:*:) where
    associative = isoF to_ from_
      where
        to_   (x :*: (y :*: z)) = (x :*: y) :*: z
        from_ ((x :*: y) :*: z) = x :*: (y :*: z)

instance Semigroupoidal (:*:) where
    type SF (:*:) = NonEmptyF

    appendSF (NonEmptyF xs :*: NonEmptyF ys) = NonEmptyF (xs <> ys)
    matchSF x = case ys of
        L1 ~Proxy -> L1 y
        R1 zs     -> R1 $ y :*: zs
      where
        y :*: ys = fromListF `hright` nonEmptyProd x

    consSF (x :*: NonEmptyF xs) = NonEmptyF $ x :| toList xs
    toSF   (x :*: y           ) = NonEmptyF $ x :| [y]

    retractS (x :*: y) = x <!> y
    interpretS f g (x :*: y) = f x <!> g y

instance Associative Day where
    associative = isoF D.assoc D.disassoc

instance Semigroupoidal Day where
    type SF Day = Ap1

    appendSF (Day x y z) = z <$> x <.> y
    matchSF a = case fromAp `hright` ap1Day a of
      Day x y z -> case y of
        L1 (Identity y') -> L1 $ (`z` y') <$> x
        R1 ys            -> R1 $ Day x ys z

    consSF (Day x y z) = Ap1 x $ flip z <$> toAp y
    toSF   (Day x y z) = z <$> inject x <.> inject y

    retractS (Day x y z) = z <$> x <.> y
    interpretS f g (Day x y z) = z <$> f x <.> g y

instance Associative (:+:) where
    associative = isoF to_ from_
      where
        to_ = \case
          L1 x      -> L1 (L1 x)
          R1 (L1 y) -> L1 (R1 y)
          R1 (R1 z) -> R1 z
        from_ = \case
          L1 (L1 x) -> L1 x
          L1 (R1 y) -> R1 (L1 y)
          R1 z      -> R1 (R1 z)

instance Semigroupoidal (:+:) where
    type SF (:+:) = Step

    appendSF = \case
      L1 x          -> x
      R1 (Step n y) -> Step (n + 1) y
    matchSF = hright R1 . stepDown

    consSF = \case
      L1 x          -> Step 0       x
      R1 (Step n y) -> Step (n + 1) y
    toSF = \case
      L1 x -> Step 0 x
      R1 y -> Step 1 y

    retractS = \case
      L1 x -> x
      R1 y -> y
    interpretS f g = \case
      L1 x -> f x
      R1 y -> g y

instance Associative Comp where
    associative = isoF to_ from_
      where
        to_   (x :>>= y) = (x :>>= (unComp . y)) :>>= id
        from_ ((x :>>= y) :>>= z) = x :>>= ((:>>= z) . y)

instance Semigroupoidal Comp where
    type SF Comp = Free1

    appendSF (x :>>= y) = x >>- y
    matchSF x = runFree1 x
        (\y n -> L1 (n <$> y))
        (\y n -> R1 (y :>>= ((\case L1 z -> inject z; R1 zs -> consSF zs) . n)))

    consSF (x :>>= y) = liftFree1 x >>- y
    toSF   (x :>>= g) = liftFree1 x >>- inject . g

    retractS       (x :>>= y) = x >>- y
    interpretS f g (x :>>= y) = f x >>- (g . y)
