#!/usr/bin/env stack
{-# LANGUAGE InstanceSigs        #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE ScopedTypeVariables #-}

{-
    stack
    script
    --resolver lts-13.16
    --package transformers
-}
import           Control.Monad.IO.Class
import           Control.Monad.Trans.Identity (IdentityT (..))
import           Control.Monad.Trans.Reader   (ReaderT (..))

-- This function is a simpler version of the example given in
-- http://hackage.haskell.org/package/unliftio
test :: (String -> IO ()) -> IO ()
test f = f "test"

test2 :: (String -> ReaderT env IO ()) -> ReaderT env IO ()
test2 f = withRunInIO $ \runReaderTAndId -> test (runReaderTAndId . f)
                     -- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ inner in withRunInIO
                     -- The runReaderTAndId here is the function that is passed to
                     -- `inner` down below. Therefore, runReaderTAndId is (id' . flip
                     -- runReaderT r). On a broader level, that just runs the ReaderT
                     -- and also runs it through the identity function. The reason for
                     -- the identity function is that inside the ReaderT we have IO so
                     -- there's no additional unwrapping needed.

main :: IO ()
main = runReaderT (test2 myPrint) "Environment"
                      -- ^^^^^^^ f in test2

myPrint :: String -> ReaderT String IO ()
myPrint string = ReaderT $ \env -> print $ env ++ " " ++ string

instance MonadUnliftIO IO where
  withRunInIO inner = inner id

instance MonadUnliftIO m => MonadUnliftIO (ReaderT r m) where
  withRunInIO :: ((forall a. ReaderT r m a -> IO a) -> IO b) -> ReaderT r m b
  withRunInIO inner =
    ReaderT $ \env -> withRunInIO $ \id' -> inner (id' . (`runReaderT` env))

class MonadIO m =>
      MonadUnliftIO m
  where
  withRunInIO :: ((forall a. m a -> IO a) -> IO b) -> m b
