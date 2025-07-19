import torch
import torch.nn as nn
from mlagents.trainers.ppo.policy import PPOPolicy
from mlagents.trainers.brain import BrainParameters
from mlagents_envs.base_env import BehaviorSpec

# Твоя нейронная сеть
class SimpleAgentNet(nn.Module):
    def __init__(self, obs_size, action_size):
        super(SimpleAgentNet, self).__init__()
        self.fc1 = nn.Linear(obs_size, 128)
        self.fc2 = nn.Linear(128, 64)
        self.fc3 = nn.Linear(64, action_size)

    def forward(self, x):
        if x.dim() == 1:
            x = x.unsqueeze(0)
        x = torch.relu(self.fc1(x))
        x = torch.relu(self.fc2(x))
        x = self.fc3(x)
        return x

# Кастомная политика с твоей сетью
class CustomPPOPolicy(PPOPolicy):
    def __init__(self, behavior_spec: BehaviorSpec, trainer_params):
        super().__init__(behavior_spec, trainer_params)
        self.model = SimpleAgentNet(
            behavior_spec.observation_specs[0].shape[0],
            behavior_spec.action_spec.continuous_size
        ).to(torch.device("cuda" if torch.cuda.is_available() else "cpu"))
        self.optimizer = torch.optim.Adam(self.model.parameters(), lr=1e-3)

    def evaluate(self, observations):
        with torch.no_grad():
            return self.model(observations)

    def update(self, mini_batch):
        # Здесь можно добавить кастомную логику обновления, но базовый PPO сделает это
        return super().update(mini_batch)