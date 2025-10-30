import json
from pathlib import Path

NB_PATH = Path('TrainAgentNewGPU.ipynb')


def get_code_cells(nb):
    return [i for i, c in enumerate(nb.get('cells', [])) if c.get('cell_type') == 'code']


def split_src(cell):
    return ''.join(cell.get('source', [])).splitlines(keepends=True)


def main():
    nb = json.loads(NB_PATH.read_text(encoding='utf-8'))

    code_positions = get_code_cells(nb)
    # We assume there are at least 7 code cells (0..6) as observed.
    # For each known cell, add explanatory comments directly into the source.

    for ordinal, idx in enumerate(code_positions):
        cell = nb['cells'][idx]
        lines = split_src(cell)

        if ordinal == 0:
            new = [
                "# Команда для установки нужных библиотек в окружение (оставлена закомментированной, запускайте при необходимости).\n",
                "# Устанавливаются: mlagents, stable-baselines3, gymnasium, PyTorch с CUDA 11.8 и torchvision совместимой версии.\n",
                "# Флаг -f указывает индекс колёс PyTorch с нужной сборкой.\n",
            ]
            # Keep original single line as-is
            new.extend(lines)
            cell['source'] = new
            continue

        if ordinal == 1:
            new = []
            import_map = [
                "# Импорт стандартного модуля для работы с путями и окружением\n",
                "# Импорт NumPy для работы с массивами и численными операциями\n",
                "# Импорт PyTorch — основной фреймворк для нейросети и вычислений на GPU\n",
                "# Импорт базового модуля нейросетей PyTorch (слои, функции активации и т.д.)\n",
                "# Импорт Python API для Unity ML-Agents (класс для управления окружением)\n",
                "# Импорт канала конфигурации движка Unity (настройка скорости, качества и пр.)\n",
                "# Импорт контейнера действий (непрерывных/дискретных) для передачи в Unity\n",
                "# Импорт алгоритма PPO из Stable-Baselines3\n",
                "# Импорт базового экстрактора признаков для пользовательской архитектуры policy/value\n",
                "# Импорт утилиты проверки совместимости окружения с Gym API\n",
                "# Импорт Gymnasium — интерфейс окружения, совместимый со Stable-Baselines3\n",
                "# Импорт наборов пространств (Box, Discrete) для описания наблюдений/действий\n",
            ]
            import_i = 0
            for line in lines:
                if line.strip().startswith('#') and '����' in line:
                    new.append("# Импорт библиотек и утилит\n")
                    continue
                if import_i < len(import_map) and (line.startswith('import') or line.startswith('from')):
                    new.append(import_map[import_i])
                    import_i += 1
                if line.startswith('def close_unity_env'):
                    new.append("# Объявление вспомогательной функции для корректного закрытия Unity-окружения и процессов\n")
                new.append(line)

            # Targeted insertions above specific lines
            def insert_above(block, startswith, comment):
                out = []
                for l in block:
                    if l.startswith(startswith):
                        out.append(comment)
                    out.append(l)
                return out

            new = insert_above(new, 'env_path', "# Абсолютный путь к скомпилированному Unity-окружению (измените при переносе проекта)\n")
            new = insert_above(new, 'engine_channel = EngineConfigurationChannel()', "# Создаём канал конфигурации движка Unity для ускорения симуляции и снижения качества рендера\n")
            new = insert_above(new, 'engine_channel.set_configuration_parameters', "# Увеличиваем скорость симуляции (time_scale) и ставим минимальное качество (quality_level=0)\n")
            new = insert_above(new, 'try:', "# Инициализация окружения Unity с параметрами\n")
            new = insert_above(new, 'env = UnityEnvironment', "# Создаём окружение: путь, worker_id, порт, side channels, таймаут\n")
            new = insert_above(new, 'env.reset()', "# Сбрасываем окружение, чтобы получить начальное состояние\n")
            new = insert_above(new, 'except Exception as e:', "# Если инициализация не удалась — печать ошибки и очистка\n")
            new = insert_above(new, 'if len(env.behavior_specs)', "# Проверяем, что в окружении есть хотя бы одно поведение (behavior)\n")
            new = insert_above(new, 'behavior_name =', "# Берём имя первого поведения\n")
            new = insert_above(new, "print(f'Behavior Name:", "# Печатаем имя поведения (для отладки)\n")
            new = insert_above(new, 'spec =', "# Получаем спецификацию поведения\n")
            new = insert_above(new, "print(f'Observation size:", "# Выводим размеры наблюдений\n")
            new = insert_above(new, "print(f'Continuous action size:", "# Выводим размер непрерывных действий\n")
            new = insert_above(new, "print(f'Discrete action branches:", "# Выводим структуру дискретных ветвей (если есть)\n")
            cell['source'] = new
            continue

        if ordinal == 2:
            new = []
            for line in lines:
                if line.startswith('class CustomActorCriticNet'):
                    new.append("# Определяем пользовательский экстрактор признаков для политики/критика SB3\n")
                if line.strip().startswith('def __init__'):
                    new.append("# Конструктор принимает пространство наблюдений и размер выходных признаков\n")
                if 'super(CustomActorCriticNet' in line:
                    new.append("# Инициализация базового класса SB3\n")
                if 'self.fc1' in line:
                    new.append("# Полносвязный слой: вход — размер наблюдения, выход — 128 (на выбранном устройстве)\n")
                if 'self.fc2' in line:
                    new.append("# Второй полносвязный слой: 128 -> 64 (на выбранном устройстве)\n")
                if 'self.fc3' in line:
                    new.append("# Третий полносвязный слой: 64 -> features_dim\n")
                if 'self.relu' in line:
                    new.append("# Функция активации ReLU\n")
                if line.strip().startswith('def forward'):
                    new.append("# Прямой проход: последовательно применяем слои и активации\n")
                if 'x = self.relu(self.fc1' in line:
                    new.append("# Признаки после первого слоя и ReLU\n")
                if 'x = self.relu(self.fc2' in line:
                    new.append("# Признаки после второго слоя и ReLU\n")
                if 'x = self.fc3' in line:
                    new.append("# Итоговые признаки после третьего слоя\n")
                new.append(line)
            out = []
            for l in new:
                if l.startswith('policy_kwargs'):
                    out.append("# Аргументы для политики PPO: экстрактор признаков и архитектура голов\n")
                if 'features_extractor_class' in l:
                    out.append("# Указываем пользовательский класс экстрактора признаков\n")
                if 'features_extractor_kwargs' in l:
                    out.append("# Параметры для конструктора экстрактора (размер выходных признаков)\n")
                if 'net_arch' in l:
                    out.append("# Архитектура policy (pi) и value (vf): два слоя 64 и 32\n")
                out.append(l)
            cell['source'] = out
            continue

        if ordinal == 3:
            new = []
            for line in lines:
                if line.startswith('class UnityGymWrapper'):
                    new.append("# Обёртка Unity ML-Agents под интерфейс Gymnasium\n")
                if line.strip().startswith('def __init__'):
                    new.append("# Конструктор получает UnityEnvironment, имя поведения и спецификацию\n")
                if 'super(UnityGymWrapper' in line:
                    new.append("# Инициализация базового класса Gym.Env\n")
                if 'self.env =' in line:
                    new.append("# Сохраняем ссылку на Unity-окружение\n")
                if 'self.behavior_name' in line:
                    new.append("# Имя поведения для обмена данными шагов\n")
                if 'self.spec =' in line:
                    new.append("# Спецификация поведения (размеры obs/action)\n")
                if 'self.observation_space' in line:
                    new.append("# Пространство наблюдений: непрерывный вектор float32\n")
                if 'self.action_space' in line:
                    new.append("# Пространство действий: непрерывное, диапазон [-1,1]\n")
                if line.strip().startswith('def reset'):
                    new.append("# Сброс окружения по API Gymnasium: возвращаем (obs, info)\n")
                if 'self.env.reset()' in line:
                    new.append("# Сбрасываем Unity-окружение\n")
                if 'decision_steps, _ = self.env.get_steps' in line:
                    new.append("# Получаем текущие шаги решающих состояний\n")
                if 'obs = decision_steps.obs' in line:
                    new.append("# Берём первое наблюдение первого агента\n")
                if line.strip().startswith('def step'):
                    new.append("# Один шаг среды по API Gymnasium\n")
                if 'action = np.array' in line:
                    new.append("# Гарантируем форму действия (1, размер_действия)\n")
                if 'action_tuple = ActionTuple' in line:
                    new.append("# Создаём контейнер действий Unity\n")
                if 'action_tuple.add_continuous' in line:
                    new.append("# Добавляем непрерывные действия\n")
                if 'self.env.set_actions' in line:
                    new.append("# Передаём действия агенту\n")
                if 'self.env.step()' in line:
                    new.append("# Продвигаем симуляцию на один шаг\n")
                if 'decision_steps, terminal_steps' in line:
                    new.append("# Считываем решения и терминальные шаги\n")
                if 'done =' in line:
                    new.append("# Флаг завершения эпизода\n")
                if "reward = float(terminal_steps.reward[0])" in line:
                    new.append("# Награда и наблюдение при завершении эпизода\n")
                if "reward = float(decision_steps.reward[0])" in line:
                    new.append("# Награда и наблюдение при продолжающемся эпизоде\n")
                if 'truncated = False' in line:
                    new.append("# Усечение не используется — False\n")
                if line.strip().startswith('def close'):
                    new.append("# Закрытие окружения с помощью вспомогательной функции\n")
                new.append(line)
            cell['source'] = new
            continue

        if ordinal == 4:
            new = []
            for line in lines:
                if line.strip().startswith('try:'):
                    new.append("# Обучение модели PPO на выбранном устройстве\n")
                if 'device =' in line:
                    new.append("# Определяем устройство: 'cuda' если доступно, иначе 'cpu'\n")
                if line.strip().startswith('model = PPO('):
                    new.append("# Создаём и настраиваем модель PPO из SB3\n")
                if "'MlpPolicy'" in line:
                    new.append("# Используем MLP-политику\n")
                if 'policy_kwargs' in line:
                    new.append("# Передаём пользовательский экстрактор и архитектуру голов\n")
                if 'learning_rate' in line:
                    new.append("# Скорость обучения Adam\n")
                if 'n_steps' in line and 'model.learn' not in line:
                    new.append("# Количество шагов в буфере до обновления\n")
                if 'batch_size' in line:
                    new.append("# Размер мини-батча\n")
                if 'n_epochs' in line:
                    new.append("# Число эпох прохода по буферу\n")
                if 'gamma' in line:
                    new.append("# Коэффициент дисконтирования\n")
                if 'gae_lambda' in line:
                    new.append("# Параметр GAE\n")
                if 'clip_range' in line:
                    new.append("# Порог обрезки PPO\n")
                if 'ent_coef' in line:
                    new.append("# Энтропийная регуляризация\n")
                if 'verbose' in line:
                    new.append("# Уровень логгирования\n")
                if 'device=' in line:
                    new.append("# Устройство вычислений (GPU/CPU)\n")
                if 'model.learn' in line:
                    new.append("# Запускаем процесс обучения\n")
                if "model.save('ppo_myagent_gpu')" in line:
                    new.append("# Сохраняем обученную модель\n")
                if "if device == 'cuda':" in line:
                    new.append("# Если используется CUDA — выводим информацию о GPU\n")
                if 'torch.cuda.get_device_name' in line:
                    new.append("# Название видеокарты\n")
                if 'torch.cuda.get_device_properties' in line:
                    new.append("# Объем памяти GPU в ГБ\n")
                if line.strip().startswith('except Exception as e:'):
                    new.append("# Обработка ошибок обучения\n")
                if line.strip().startswith('finally:'):
                    new.append("# В любом случае закрываем окружение\n")
                new.append(line)
            cell['source'] = new
            continue

        if ordinal == 5:
            new = []
            for line in lines:
                if line.strip() == 'import torch':
                    new.append("# Импорт PyTorch (на случай изолированного запуска ячейки)\n")
                if 'from torch.nn import Parameter' in line:
                    new.append("# Импорт Parameter для хранения констант в модуле\n")
                if line.strip().startswith('class WrapperNet'):
                    new.append("# Обёртка над политикой для экспорта в ONNX/Unity Sentis\n")
                if line.strip().startswith('def __init__'):
                    new.append("# Принимает политику SB3 и размер непрерывного действия\n")
                if 'self.policy = policy' in line:
                    new.append("# Сохраняем ссылку на политику\n")
                if 'version_number = ' in line and 'Parameter' not in line:
                    new.append("# Версия формата (MLAgents2_0 = 3)\n")
                if 'self.version_number' in line:
                    new.append("# Регистрируем как неизменяемый параметр\n")
                if 'memory_size = ' in line and 'Parameter' not in line:
                    new.append("# Размер памяти RNN = 0 (RNN не используется)\n")
                if 'self.memory_size' in line:
                    new.append("# Регистрируем память как константу\n")
                if 'continuous_shape = ' in line and 'Parameter' not in line:
                    new.append("# Форма выхода непрерывных действий\n")
                if 'self.continuous_shape' in line:
                    new.append("# Регистрируем форму как константу\n")
                if line.strip().startswith('def forward'):
                    new.append("# Прямой проход: возвращаем действия и служебные тензоры\n")
                if 'self.policy(obs, deterministic=True)[0]' in line:
                    new.append("# Получаем детерминированные действия из политики\n")
                if 'torch.mul(continuous_actions, mask)' in line:
                    new.append("# Применяем маску действий (элементное умножение)\n")
                if line.strip().startswith('try:'):
                    new.append("# Экспорт модели в ONNX с обработкой ошибок\n")
                if 'policy = model.policy.to(device)' in line:
                    new.append("# Переносим политику на нужное устройство\n")
                if 'continuous_action_size = ' in line:
                    new.append("# Получаем размер непрерывного действия из спецификации\n")
                if 'wrapper_net = WrapperNet' in line:
                    new.append("# Создаём обёртку для экспорта\n")
                if 'dummy_input' in line:
                    new.append("# Заглушка входа: случайное наблюдение формы [1, obs_size]\n")
                if 'dummy_mask' in line:
                    new.append("# Заглушка маски действий: все действия доступны\n")
                if 'torch.onnx.export(' in line:
                    new.append("# Экспорт в ONNX: задаём имена входов/выходов и динамические оси\n")
                if 'opset_version=' in line:
                    new.append("# Версия опсета ONNX, совместимая с Unity Sentis\n")
                if "print('" in line and 'trained_myagent.onnx' in ''.join(lines):
                    new.append("# Сообщение об успешном экспорте и проверка наличия файла\n")
                if line.strip().startswith('except Exception as e:'):
                    new.append("# Обработка ошибок экспорта: совет сменить opset при проблемах\n")
                if line.strip().startswith('finally:'):
                    new.append("# Закрываем окружение в любом случае\n")
                new.append(line)
            cell['source'] = new
            continue

        if ordinal == 6:
            new = []
            for line in lines:
                if line.strip().startswith('try:'):
                    new.append("# Тестовое выполнение модели в окружении\n")
                if 'obs, _ = gym_env.reset()' in line:
                    new.append("# Сбрасываем окружение и получаем начальное наблюдение\n")
                if 'for _ in range(1000):' in line:
                    new.append("# Выполняем до 1000 шагов\n")
                if 'model.predict' in line:
                    new.append("# Предсказываем действие по наблюдению (детерминированно)\n")
                if 'gym_env.step' in line:
                    new.append("# Делаем шаг в среде\n")
                if 'if done or truncated' in line:
                    new.append("# Если эпизод завершён/усечён — начинаем заново\n")
                if line.strip().startswith('except Exception as e:'):
                    new.append("# Обработка ошибок тестирования\n")
                if line.strip().startswith('finally:'):
                    new.append("# Закрываем окружение в любом случае\n")
                new.append(line)
            cell['source'] = new
            continue

    NB_PATH.write_text(json.dumps(nb, ensure_ascii=False, indent=1), encoding='utf-8')
    print('OK')


if __name__ == '__main__':
    main()

