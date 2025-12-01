# My First NPC — Техническая документация

## Обзор репозитория
- **Environment/** — собранная Unity-сцена (`UnityEnvironment.exe`) с настроенным поведением агента `MyAgent?team=0` и поддержкой непрерывных действий. Файлы D3D12/DirectML и UnityPlayer.dll нужны для запуска окружения вне редактора.
- **Brains/trained_myagent.onnx** — экспортированная ONNX-модель политики для использования в Unity Sentis.
- **TrainAgentNewGPU_1.1.ipynb** — основной Jupyter Notebook для обучения агента (PPO) и экспорта политики в ONNX.
- **Старые_версии_Train/** — архив предыдущих ноутбуков обучения (на случай отката или сравнения подходов).
- **requirements.txt** — список зависимостей Python для воспроизведения ноутбука.
- **tools/update_notebook_comments.\*** — вспомогательные скрипты для автокомментирования старого ноутбука.

## Настройка Unity-проекта и окружения
- Сборка окружения ожидает поведение `MyAgent?team=0` с **6 наблюдениями** и **2 непрерывными действиями**; дискретные действия отсутствуют.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- В ноутбуке путь к сборке задаётся абсолютной строкой `N:\\MyRL\\My_First_NPC\\Environment\\UnityEnvironment.exe`; при переносе проекта обновите `env_path` на актуальный путь к `UnityEnvironment.exe`.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- Канал `EngineConfigurationChannel` ускоряет симуляцию (`time_scale=20.0`) и снижает качество рендера (`quality_level=0`) для производительности при обучении.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- Окружение инициализируется с `worker_id=1` и `base_port=6000`, после чего извлекается спецификация поведения и проверяется размер наблюдений/действий.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- Unity-экземпляр корректно закрывается через вспомогательную функцию `close_unity_env`, которая при необходимости завершает зависшие процессы `UnityEnvironment.exe`.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】

## API-взаимодействие: Unity ↔ Python
- Общение происходит через Python API **mlagents_envs**: `UnityEnvironment` управляет запуском/шагами сборки, а действия отправляются через `ActionTuple` с непрерывными значениями в диапазоне [-1, 1].【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- Для интеграции с библиотеками RL используется `UnityGymWrapper`, реализующий интерфейс `gym.Env`: определяет пространства наблюдений/действий, преобразует выходы Unity в формат Gymnasium и передаёт действия обратно в среду.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- В `step` данные собираются через `get_steps`; при наличии терминального шага награда и наблюдение берутся из `terminal_steps`, иначе — из `decision_steps`. Возвращается кортеж `(obs, reward, done, truncated, info)` совместимый со Stable-Baselines3.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- Валидация обёртки выполняется вызовом `check_env(gym_env)` из Stable-Baselines3 для проверки соответствия API Gym.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】

## Jupyter Notebook: запуск и назначение
- **TrainAgentNewGPU_1.1.ipynb** содержит полный цикл: установка зависимостей, инициализация Unity-среды, подготовка обёртки Gym, обучение PPO и экспорт ONNX.
- Ключевые зависимости (версии фиксированы для CUDA 11.8): `mlagents==0.30.0`, `stable-baselines3==2.0.0`, `gymnasium==0.28.1`, `torch==2.0.1`, `torchvision==0.15.2`, `onnx`, `psutil` (установку можно выполнить из первой ячейки или через `pip install -r requirements.txt`).【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】【F:requirements.txt†L1-L11】
- Шаги ноутбука:
  1. **Импорт модулей** и объявление `close_unity_env` для безопасного завершения процессов Unity.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】 
  2. **Создание Unity-среды** и чтение `behavior_specs` для вывода размеров наблюдений/действий.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
  3. **Обёртка Gym** (`UnityGymWrapper`) для совместимости со Stable-Baselines3.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
  4. **Обучение PPO** с заданными гиперпараметрами и сохранением модели `ppo_myagent_gpu`.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
  5. **Экспорт в ONNX** через обёртку `WrapperNet`, добавляющую метаданные (`continuous_action_output_shape`, `version_number`, `memory_size`) и dummy-маску действий для корректной трассировки графа.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
  6. **Тестирование**: прогон обученной политики в среде в детерминированном режиме с переподключением при завершении эпизода.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- В папке **Старые_версии_Train/** хранятся более ранние ноутбуки (Train.ipynb, TrainAgent*.ipynb) для сравнения; основная рабочая версия — `TrainAgentNewGPU_1.1.ipynb`.【5d3829†L1-L2】

## Архитектура нейронной сети и процесс обучения
- **Feature extractor (CustomActorCriticNet)** — MLP с тремя полносвязными слоями: `obs_dim → 128 → 64 → features_dim (128)` с активацией ReLU после первых двух слоёв; предоставляет выход признаков для политики и критика.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- **Policy/value heads** задаются через `net_arch=[dict(pi=[64, 32], vf=[64, 32])]`, т.е. отдельные MLP-головы политики и ценности с двумя слоями (64 и 32 нейрона).【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- **Алгоритм**: PPO (`stable-baselines3`), ключевые гиперпараметры — `learning_rate=3e-4`, `n_steps=2048`, `batch_size=64`, `n_epochs=10`, `gamma=0.99`, `gae_lambda=0.95`, `clip_range=0.2`, `ent_coef=0.01`; обучение на CPU или CUDA в зависимости от `torch.cuda.is_available()`, количество шагов — 100000.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- **Экспорт модели**: политика SB3 оборачивается в `WrapperNet`, который возвращает тензоры действий и метаданных; экспортируется в `trained_myagent.onnx` с динамическими осями batch и opset 9 (при необходимости можно увеличить до 11/12).【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- **Тест**: детерминированный `model.predict` в цикле 1000 шагов для проверки корректности поведения и сбросов эпизодов; среда закрывается после теста через `close_unity_env`.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】

## Интеграция модели в Unity (Sentis)
- Сохранённая ONNX-модель (`Brains/trained_myagent.onnx`) соответствует формату ML-Agents v3: входы `obs_0` (наблюдения) и `action_masks`, выходы `continuous_actions`, `continuous_action_output_shape`, `version_number`, `memory_size` (последние три включены как неизменяемые параметры).【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
- В Unity Sentis нужно обеспечить подачу наблюдений размером 6 и маски действий размером 2, а также считать непрерывные действия из первого выхода.

## Быстрый старт
1. Установите зависимости: `pip install -r requirements.txt` (или выполните первую ячейку ноутбука).【F:requirements.txt†L1-L11】
2. Обновите `env_path` в ноутбуке на путь к вашей сборке `UnityEnvironment.exe` и убедитесь, что CUDA/драйверы соответствуют указанной версии PyTorch.【F:TrainAgentNewGPU_1.1.ipynb†L1-L1】
3. Запустите ноутбук по шагам: инициализация окружения → `UnityGymWrapper` → блок обучения → экспорт ONNX → тестовый прогон.
4. Подключите `Brains/trained_myagent.onnx` в Unity Sentis, передавая наблюдения и маску действий, чтобы воспроизвести поведение обученного агента.
