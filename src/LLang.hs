module LLang where

import Control.Applicative (Alternative (..))
import AST (AST (..), Operator (..), Subst (..))
import Combinators 
import Expr hiding (parseExpr)
import UberExpr
import Data.Char
import qualified Data.Map as Map
import Data.List (intercalate)
import Text.Printf (printf)


type Expr = AST

type Var = String

data Configuration = Conf { subst :: Subst, input :: [Int], output :: [Int] }
                   deriving (Show, Eq)


data Program = Program { functions :: [Function], main :: LAst }

data Function = Function { name :: String, args :: [Var], funBody :: LAst }

instance Eq Function where
   (==) (Function n1 a1 b1) (Function n2 a2 b2) = (n1 == n2) && (a1 == a2) && (b1 == b2)

instance Eq Program where
   (==) (Program f1 m1) (Program f2 m2) = (f1 == f2) && (m1 == m2)

data LAst
  = If { cond :: Expr, thn :: LAst, els :: LAst }
  | While { cond :: AST, body :: LAst }
  | Assign { var :: Var, expr :: Expr }
  | Read { var :: Var }
  | Write { expr :: Expr }
  | Seq { statements :: [LAst] }
  | Return { expr :: Expr }
  deriving (Eq)

parseArgs = ((++) <$> (many parseSeqArg) <*> (parseOneArg)) <|> (parseOneArg) where
    parseSeqArg = do
        sep1 <- parseSeparators
        result <- parseIdent
        sep2 <- parseSeparators
        sep <- symbol ','
        sep3 <- parseSeparators
        sep4 <- parseSeparators
        return $ result
    parseOneArg = do
        sep1 <- parseSeparators
        result <- parseIdent
        sep4 <- parseSeparators
        return $ [result]

parseDef :: Parser String String Function
parseDef = Function <$> (simpleParseKeyword "def" *> parseIdent) <*> parseArgs' <*> parseBody where
                       parseArgs' = do
                          sep1 <- parseSeparators
                          left <- symbol '('
                          sep2 <- parseSeparators
                          result <- parseArgs
                          sep3 <- parseSeparators
                          right <- symbol ')'
                          sep4 <- parseSeparators
                          return $ result
                       parseBody = do 
                          sep1 <- parseSeparators
                          left <- symbol '{'
                          sep2 <- parseSeparators
                          result <- parseL
                          sep3 <- parseSeparators
                          right <- symbol '}'
                          sep4 <- parseSeparators
                          return $ result


parseMain :: Parser String String Function
parseMain = Function <$> (simpleParseKeyword "def" *> simpleParseKeyword "main") <*> parseArgs' <*> parseBody where
                       parseArgs' = do
                          sep1 <- parseSeparators
                          left <- symbol '('
                          sep2 <- parseSeparators
                          result <- parseArgs
                          sep3 <- parseSeparators
                          right <- symbol ')'
                          sep4 <- parseSeparators
                          return $ result
                       parseBody = do 
                          sep1 <- parseSeparators
                          left <- symbol '{'
                          sep2 <- parseSeparators
                          result <- parseL
                          sep3 <- parseSeparators
                          right <- symbol '}'
                          sep4 <- parseSeparators
                          return $ result


parseProg :: Parser String String Program
parseProg = parseFuncs where
          parseFunc = do
             sep1 <- parseSeparators
             result <- parseDef
             sep2 <- parseSeparators
             end <- symbol ';'
             return $ result
          parseM = do
             sep1 <- parseSeparators
             result <- parseMain
             sep2 <- parseSeparators
             end <- symbol ';'
             return $ result
          parseFuncs = do 
             main <- parseM
             funcs <- many parseFunc
             return $ Program funcs (funBody main)
          
          
            
          
stmt :: LAst
stmt =
  Seq
    [ Read "X"
    , If (BinOp Gt (Ident "X") (Num 13))
         (Write (Ident "X"))
         (While (BinOp Lt (Ident "X") (Num 42))
                (Seq [ Assign "X"
                        (BinOp Mult (Ident "X") (Num 7))
                     , Write (Ident "X")
                     ]
                )
         )
    ]



satisfyStr :: String  -> Parser String String String
satisfyStr w = Parser $ \(InputStream input (Position l c)) ->
  let (pref, suff) = splitAt (length w) input in
  if pref == w
  then Success (InputStream suff (Position l (c + length w))) Nothing w
  else Failure (makeError ("Expected " ++ show w) (Position l c))
     
simpleParseKeyword s = parseSeparators *> (satisfyStr s) <* parseSeparators

--------------------------------------------------------------------------

-- добавила в Ast.hs T и F 
toAST :: String -> Parser String String AST
toAST "true" = return $ T
toAST "false" = return $ F

-- старый парсер для выражений без унарного минуса
parseExpr :: Parser String String AST
parseExpr =  uberExpr [(parseOrOp, Binary RightAssoc),
                     (parseAndOp, Binary RightAssoc),
                     (parseNotOp, Unary),
                     (parseGeqOp <|> parseLeqOp <|> parseLtOp <|> parseGtOp <|> parseEqOp <|> parseNeqOp, Binary NoAssoc),
                     (parseAddOp <|> parseSubOp, Binary LeftAssoc),
                     (parseMultOp <|> parseDivOp, Binary LeftAssoc),
                     (parsePowOp, Binary RightAssoc)]
           (Num <$> parseNum <|> symbol '(' *> parseExpr <* symbol ')' <|> Ident <$> parseIdent)
           BinOp
           UnaryOp
           where
               parseMultOp = symbol '*' >>= toOperator
               parseAddOp = symbol '+' >>= toOperator
               parseSubOp = symbol '-' >>= toOperator
               parseDivOp = symbol '/' >>= toOperator
               parsePowOp = symbol '^' >>= toOperator
               parseLtOp = symbol '<' >>= toOperator
               parseGtOp = symbol '>' >>= toOperator
               parseNotOp = symbol '!' >>= toOperator
               parseOrOp = (:) <$> (symbol '|') <*> ((:[]) <$> (symbol '|')) >>= toOperatorStr
               parseAndOp = (:) <$> (symbol '&') <*> ((:[]) <$> (symbol '&')) >>= toOperatorStr
               parseLeqOp = (:) <$> (symbol '<') <*> ((:[]) <$> (symbol '=')) >>= toOperatorStr
               parseGeqOp = (:) <$> (symbol '>') <*> ((:[]) <$> (symbol '=')) >>= toOperatorStr
               parseEqOp = (:) <$> (symbol '=') <*> ((:[]) <$> (symbol '=')) >>= toOperatorStr
               parseNeqOp = (:) <$> (symbol '/') <*> ((:[]) <$> (symbol '=')) >>= toOperatorStr


--парсер для выражений вида: Expr LogikOp Expr
parseLogikExpr :: Parser String String AST
parseLogikExpr =  uberExpr [(parseOrOp, Binary RightAssoc),
                     (parseAndOp, Binary RightAssoc),
                     (parseGeqOp <|> parseLeqOp <|> parseLtOp <|> parseGtOp <|> parseEqOp <|> parseNeqOp, Binary NoAssoc)
                     ]
           (Num <$> parseNum <|> symbol '(' *> parseExpr <* symbol ')' <|> Ident <$> parseIdent)
           BinOp
           UnaryOp
           where
               parseMultOp = symbol '*' >>= toOperator
               parseAddOp = symbol '+' >>= toOperator
               parseSubOp = symbol '-' >>= toOperator
               parseDivOp = symbol '/' >>= toOperator
               parsePowOp = symbol '^' >>= toOperator
               parseLtOp = symbol '<' >>= toOperator
               parseGtOp = symbol '>' >>= toOperator
               parseNotOp = symbol '!' >>= toOperator
               parseOrOp = (:) <$> (symbol '|') <*> ((:[]) <$> (symbol '|')) >>= toOperatorStr
               parseAndOp = (:) <$> (symbol '&') <*> ((:[]) <$> (symbol '&')) >>= toOperatorStr
               parseLeqOp = (:) <$> (symbol '<') <*> ((:[]) <$> (symbol '=')) >>= toOperatorStr
               parseGeqOp = (:) <$> (symbol '>') <*> ((:[]) <$> (symbol '=')) >>= toOperatorStr
               parseEqOp = (:) <$> (symbol '=') <*> ((:[]) <$> (symbol '=')) >>= toOperatorStr
               parseNeqOp = (:) <$> (symbol '/') <*> ((:[]) <$> (symbol '=')) >>= toOperatorStr


--возможно выражение: !(Expr LogikOp Expr) -- без пробелов между cкобками и '!'
parseCondition = parseSeparators *> parseInside <* parseSeparators
               where
                   parseTrue = (simpleParseKeyword "true") >>= toAST
                   parseFalse = (simpleParseKeyword "false") >>= toAST
                   parseNotLogikExpr = do
                      not <- symbol '!'
                      left <- symbol '('
                      result <- parseLogikExpr
                      right <- symbol ')'
                      return $ UnaryOp Not result
                   parseInside = parseTrue <|> parseFalse <|> parseLogikExpr <|> parseNotLogikExpr
 
 
                  
parseAssign = Assign <$> parseId <*> (symbol '=' *> parseExp)
            where 
               parseId = parseSeparators *> parseIdent <* parseSeparators
               parseExp = parseSeparators *> parseExpr <* parseSeparators

parseRead = Read <$> (simpleParseKeyword "read" *> parseR) where
                    parseR = do 
                      sep1 <- parseSeparators
                      left <- symbol '('
                      sep2 <- parseSeparators
                      result <- parseIdent
                      sep3 <- parseSeparators
                      right <- symbol ')'
                      sep4 <- parseSeparators
                      return $ result

parseWrite = Write <$> (simpleParseKeyword "write" *> parseW) where
                parseW = do 
                      sep1 <- parseSeparators
                      left <- symbol '('
                      sep2 <- parseSeparators
                      result <- parseExpr
                      sep3 <- parseSeparators
                      right <- symbol ')'
                      sep4 <- parseSeparators
                      return $ result

parseWhile = While <$> (simpleParseKeyword "while" *> parseC) <*> parseS where
                        parseC = do 
                          sep1 <- parseSeparators
                          left <- symbol '('
                          sep2 <- parseSeparators
                          result <- parseCondition
                          sep3 <- parseSeparators
                          right <- symbol ')'
                          sep4 <- parseSeparators
                          return $ result
                        parseS = do 
                          sep1 <- parseSeparators
                          left <- symbol '{'
                          sep2 <- parseSeparators
                          result <- parseSeq
                          sep3 <- parseSeparators
                          right <- symbol '}'
                          sep4 <- parseSeparators
                          return $ result

parseIf = If <$> (simpleParseKeyword "if" *> parseC) <*> parseS <*> (simpleParseKeyword "else" *> parseS ) where
                        parseC = do 
                          sep1 <- parseSeparators
                          left <- symbol '('
                          sep2 <- parseSeparators
                          result <- parseCondition
                          sep3 <- parseSeparators
                          right <- symbol ')'
                          sep4 <- parseSeparators
                          return $ result
                        parseS = do 
                          sep1 <- parseSeparators
                          left <- symbol '{'
                          sep2 <- parseSeparators
                          result <- parseSeq
                          sep3 <- parseSeparators
                          right <- symbol '}'
                          sep4 <- parseSeparators
                          return $ result

parseReturn = Return <$> (simpleParseKeyword "return" *> parseE) where
                parseE = do 
                      sep2 <- parseSeparators
                      result <- parseExpr
                      sep3 <- parseSeparators
                      return $ result

parseEnd = simpleParseKeyword ";"

parseStatment = (parseSt parseIf) <|> (parseSt parseWhile) <|> (parseSt parseWrite) <|> (parseSt parseRead) <|> (parseSt parseAssign) <|>(parseSt parseReturn)
               where
                  parseSt parser = do 
                     sep1 <- parseSeparators
                     result <- parser
                     sep2 <- parseSeparators
                     ens <- parseEnd
                     sep3 <- parseSeparators
                     return $ result

parseStatments =  many parseStatment

parseSeparator :: Parser String String Char
parseSeparator = (satisfy isSeparator) <|> (symbol '\n')

parseSeparators = many parseSeparator

parseSeq :: Parser String String LAst
parseSeq = Seq <$> (parseSeparators *> parseStatments <* parseSeparators)

parseL :: Parser String String LAst
parseL = parseSeq


initialConf :: [Int] -> Configuration
initialConf input = Conf Map.empty input []

getLAst :: String -> LAst
getLAst input = case runParser parseL input of 
         Success rest msg ast -> ast
         _ -> Seq []
      
        

eval :: LAst -> Configuration -> Maybe Configuration
eval (Assign var expr) (Conf dict input output) = do 
          result <- evalExpr dict expr
          let new_dict = Map.insert var result dict
          return $ Conf new_dict input output
eval (Read var) (Conf dict input output) = do
          case input of
             [] -> Nothing
             (x:xs) -> let new_dict = Map.insert var (head input) dict in 
                       return $ Conf new_dict (tail input) output
eval (Write expr) (Conf dict input output) = do
           result <- evalExpr dict expr
           return $ Conf dict input (result:output)
eval (While cond body) (Conf dict input output) = do
           result <- evalExpr dict cond
           if (intToBool result) then do
              new_conf <- eval body (Conf dict input output)
              result' <- eval (While cond body) new_conf
              return $ result'
           else return $ (Conf dict input output)
eval (If cond thn els) (Conf dict input output) = do
      result <- evalExpr dict cond
      if (intToBool result) then do
         eval thn (Conf dict input output)
      else do
         eval els (Conf dict input output)
eval (Seq []) conf = return $ conf
eval (Seq xs) (Conf dict input output) = do
        (Conf dict' input' output') <- eval (head xs) (Conf dict input output)
        eval (Seq (tail xs)) (Conf dict' input' output')


instance Show Function where
  show (Function name args funBody) =
    printf "%s(%s) =\n%s" name (intercalate ", " $ map show args) (unlines $ map (identation 1) $ lines $ show funBody)

instance Show Program where
  show (Program defs main) =
    printf "%s\n\n%s" (intercalate "\n\n" $ map show defs) (show main)

instance Show LAst where
  show =
      go 0
    where
      go n t =
        let makeIdent = identation n in
        case t of
          If cond thn els -> makeIdent $ printf "if %s\n%sthen\n%s\n%selse\n%s" (flatShowExpr cond) (makeIdent "") (go (ident n) thn) (makeIdent "") (go (ident n) els)
          While cond body -> makeIdent $ printf "while %s\n%sdo\n%s" (flatShowExpr cond) (makeIdent "") (go (ident n) body)
          Assign var expr -> makeIdent $ printf "%s := %s" var (flatShowExpr expr)
          Read var        -> makeIdent $ printf "read %s" var
          Write expr      -> makeIdent $ printf "write %s" (flatShowExpr expr)
          Seq stmts       -> intercalate "\n" $ map (go n) stmts
          Return expr     -> makeIdent $ printf "return %s" (flatShowExpr expr)
      flatShowExpr (BinOp op l r) = printf "(%s %s %s)" (flatShowExpr l) (show op) (flatShowExpr r)
      flatShowExpr (UnaryOp op x) = printf "(%s %s)" (show op) (flatShowExpr x)
      flatShowExpr (Ident x) = x
      flatShowExpr (Num n) = show n
      flatShowExpr T = show "true"
      flatShowExpr F = show "false"
      flatShowExpr (FunctionCall name args) = printf "%s(%s)" name (intercalate ", " $ map flatShowExpr args)


ident = (+1)

identation n = if n > 0 then printf "%s|_%s" (concat $ replicate (n - 1) "| ") else id
