set -x
set -o pipefail

CLIPO_PATH=${HOME}/clipo
MODEL_PATH=${HOME}/models/Qwen/Qwen2.5-3B-Instruct

cd ${CLIPO_PATH}

TRAIN_FILE_DIR=${CLIPO_PATH}/data/train
TEST_FILE_DIR=${CLIPO_PATH}/data/test
TRAIN_FILE="${TRAIN_FILE_DIR}/gsm8k.parquet"
TEST_FILE="['${TEST_FILE_DIR}/gsm8k.parquet','${TEST_FILE_DIR}/gsm_p1.parquet','${TEST_FILE_DIR}/gsm_p2.parquet','${TEST_FILE_DIR}/gsm_symbolic.parquet','${TEST_FILE_DIR}/theoremqa*2.parquet','${TEST_FILE_DIR}/mmlu2k.parquet','${TEST_FILE_DIR}/truthfulqa*2.parquet','${TEST_FILE_DIR}/commonsense_qa.parquet']"

project_name="clipo_gsm8k"
exp_name="grpo-${MODEL_PATH##*/}"

# GRPO: start
use_kl_in_reward=False
kl_coef=0.0
use_kl_loss=True
kl_loss_coef=0.001
# GRPO: end

# CLIPO: start
enable_con_lm_head=True
con_lm_head_output_size=512
con_lm_head_loss_type=infonce_loss
con_lm_head_temperature=0.05
con_lm_head_lambda=0.2
# CLIPO: end

train_batch_size=512
ppo_mini_batch_size=256
batch_size_per_gpu=32
rollout_n=16
max_prompt_length=512
max_response_length=2048
val_rollout=1
do_sample=False

n_gpus_per_node=8
nnodes=1
warmup=14
save_freq=-1
test_freq=7
total_epochs=6

offload=False # False for small model
gpu_memory_utilization=0.8
use_dynamic_bsz=True
max_num_seqs=1024
max_num_batched_tokens=$((max_prompt_length + max_response_length))
ppo_max_token_len_per_gpu=$(((max_prompt_length + max_response_length) * 2))

python3 -m verl.trainer.main_ppo \
    algorithm.adv_estimator=grpo \
    algorithm.use_kl_in_reward=${use_kl_in_reward} \
    algorithm.kl_ctrl.kl_coef=${kl_coef} \
    data.train_files=${TRAIN_FILE} \
    data.val_files=${TEST_FILE} \
    data.train_batch_size=${train_batch_size} \
    data.max_prompt_length=${max_prompt_length} \
    data.max_response_length=${max_response_length} \
    data.filter_overlong_prompts=True \
    data.truncation='error' \
    actor_rollout_ref.model.path=${MODEL_PATH} \
    actor_rollout_ref.actor.optim.lr=1e-6 \
    actor_rollout_ref.model.use_remove_padding=True \
    actor_rollout_ref.actor.ppo_mini_batch_size=${ppo_mini_batch_size} \
    actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=${batch_size_per_gpu} \
    actor_rollout_ref.actor.use_kl_loss=${use_kl_loss} \
    actor_rollout_ref.actor.kl_loss_coef=${kl_loss_coef} \
    actor_rollout_ref.actor.kl_loss_type=low_var_kl \
    actor_rollout_ref.actor.entropy_coeff=0 \
    actor_rollout_ref.actor.use_dynamic_bsz=${use_dynamic_bsz} \
    actor_rollout_ref.actor.ppo_max_token_len_per_gpu=${ppo_max_token_len_per_gpu} \
    actor_rollout_ref.model.enable_gradient_checkpointing=True \
    actor_rollout_ref.model.enable_con_lm_head=${enable_con_lm_head} \
    actor_rollout_ref.model.con_lm_head_loss_type=${con_lm_head_loss_type} \
    actor_rollout_ref.model.con_lm_head_output_size=${con_lm_head_output_size} \
    actor_rollout_ref.model.con_lm_head_temperature=${con_lm_head_temperature} \
    actor_rollout_ref.model.con_lm_head_lambda=${con_lm_head_lambda} \
    actor_rollout_ref.actor.fsdp_config.param_offload=${offload} \
    actor_rollout_ref.actor.fsdp_config.optimizer_offload=${offload} \
    actor_rollout_ref.rollout.enable_return_hidden_states=${enable_con_lm_head} \
    actor_rollout_ref.rollout.log_prob_micro_batch_size_per_gpu=${batch_size_per_gpu} \
    actor_rollout_ref.rollout.tensor_model_parallel_size=1 \
    actor_rollout_ref.rollout.name=sglang \
    actor_rollout_ref.rollout.max_num_seqs=${max_num_seqs} \
    actor_rollout_ref.rollout.max_num_batched_tokens=${max_num_batched_tokens} \
    actor_rollout_ref.rollout.gpu_memory_utilization=${gpu_memory_utilization} \
    actor_rollout_ref.rollout.n=${rollout_n} \
    actor_rollout_ref.rollout.val_kwargs.do_sample=${do_sample} \
    actor_rollout_ref.rollout.val_kwargs.n=${val_rollout} \
    actor_rollout_ref.rollout.val_kwargs.temperature=0.6 \
    actor_rollout_ref.rollout.val_kwargs.top_p=0.95 \
    actor_rollout_ref.ref.log_prob_micro_batch_size_per_gpu=${batch_size_per_gpu} \
    actor_rollout_ref.ref.fsdp_config.param_offload=${offload} \
    trainer.critic_warmup=${warmup} \
    trainer.logger='["console"]' \
    trainer.project_name=$project_name \
    trainer.experiment_name=$exp_name \
    trainer.n_gpus_per_node=${n_gpus_per_node} \
    trainer.nnodes=${nnodes} \
    trainer.save_freq=${save_freq} \
    trainer.test_freq=${test_freq} \
    trainer.total_epochs=${total_epochs} \
    2>&1 | tee -a train_gsm8k.log