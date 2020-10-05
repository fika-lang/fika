defmodule Fika.Parser.Type do
  import NimbleParsec

  defcombinator :type, Fika.Lexer.Type.type()
  defcombinator :type_args, Fika.Lexer.Type.type_args()
  defcombinator :type_args_list, Fika.Lexer.Type.type_args_list()
end
