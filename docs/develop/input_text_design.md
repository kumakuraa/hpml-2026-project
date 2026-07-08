# input_text の設計

## ablation: toolonly

###　[A] 学習時に実際にモデルへ入るテキスト:

<bos><|turn>user
{question}<turn|>
<|turn>model
#Tool1: {tool_name}<turn|>

### [B] 評価時のみ使われるテキスト:

<bos><|turn>user
You are an expert planner for industrial asset operations. Produce a structured plan.

OUTPUT FORMAT (one block per step):
#Tool1: <tool_name>

Rules: Keep plans concise. 

QUESTION: {question}<turn|>
<|turn>model