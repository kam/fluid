defmodule Fluid.Conditions do
  alias Fluid.Context, as: Context
  alias Fluid.Variable, as: Variable
  alias Fluid.Condition, as: Cond
  alias Fluid.Variables, as: Vars

  def create([h|t]) do
    head = create(h)
    create(head, t)
  end

  def create(<<left::binary>>) do
    left = Vars.create(left)
    Cond[left: left]
  end

  def create({ <<left::binary>>, operator, <<right::binary>> }) do
    create({ left |> Vars.create, operator, right |> Vars.create})
  end

  def create({ Variable[]=left, operator, <<right::binary>> }) do
    create({ left, operator, right |> Vars.create})
  end

  def create({ <<left::binary>>, operator, Variable[]=right }) do
    create({ left |> Vars.create, operator, right })
  end

  def create({ Variable[]=left, operator, Variable[]=right }) do
    operator = binary_to_atom(operator, :utf8)
    Cond[left: left, operator: operator, right: right]
  end

  def create(condition, []), do: condition
  def create(condition, [join, right|_]) when join == "and" or join == "or" do
    right = create(right)
    join  = join |> String.strip |> binary_to_atom(:utf8)
    join(join, condition, right)
  end

  def join(operator, condition, { _, _, _ }=right), do: join(operator, condition, right |> create)
  def join(operator, condition, Cond[]=right) do
    right.child_condition(condition).child_operator(operator)
  end

  def evaluate(Cond[]=condition), do: evaluate(condition, Context[])
  def evaluate(Cond[left: left, right: nil]=condition, Context[]=context) do
    { current, context } = Vars.lookup(left, context)
    eval_child(!!current, condition.child_operator, condition.child_condition, context)
  end

  def evaluate(Cond[left: left, right: right, operator: operator]=condition, Context[]=context) do
    { left, context } = Vars.lookup(left, context)
    { right, context } = Vars.lookup(right, context)
    current = eval_operator(left, operator, right)
    eval_child(!!current, condition.child_operator, condition.child_condition, context)
  end

  defp eval_child(current, nil, nil, _), do: current

  defp eval_child(current, :and, condition, context) do
    current and evaluate(condition, context)
  end

  defp eval_child(current, :or, condition, context) do
    current or evaluate(condition, context)
  end

  defp eval_operator(left, operator, right) when (nil?(left) xor nil?(right)) and operator in [:>=, :>, :<, :<=], do: false
  defp eval_operator(left, operator, right) do
    case operator do
      :== -> left == right
      :>= -> left >= right
      :>  -> left >  right
      :<= -> left <= right
      :<  -> left <  right
      :!= -> left != right
      :<> -> left != right
      :contains -> contains(left, right)
    end
  end

  defp contains(nil, _), do: false
  defp contains(_, nil), do: false
  defp contains(<<left::binary>>, <<right::binary>>), do: contains(left |> binary_to_list, right |> binary_to_list)
  defp contains(left, <<right::binary>>) when is_list(left), do: contains(left, right |> binary_to_list)
  defp contains(<<left::binary>>, right) when is_list(right), do: contains(left |> binary_to_list, right)
  defp contains(left, right) when is_list(left) and !is_list(right), do: contains(left, [right])
  defp contains(left, right) when is_list(right) and is_list(left), do: :string.rstr(left, right) > 0
end
