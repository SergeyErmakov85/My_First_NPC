$ErrorActionPreference = 'Stop'
$nbPath = 'TrainAgentNewGPU.ipynb'

function Insert-Above {
  param([object[]]$Block,[string]$StartsWith,[string]$Comment)
  $out = New-Object System.Collections.Generic.List[object]
  foreach($l in $Block){
    if($l -is [string] -and $l.StartsWith($StartsWith)){
      $out.Add($Comment)
    }
    $out.Add($l)
  }
  return ,$out.ToArray()
}

if(!(Test-Path $nbPath)){ throw "Notebook not found: $nbPath" }
$nb = Get-Content -Raw $nbPath | ConvertFrom-Json -Depth 200

# Collect indices of code cells
$codeIdx = @()
for($i=0; $i -lt $nb.cells.Count; $i++){
  if($nb.cells[$i].cell_type -eq 'code'){ $codeIdx += $i }
}

for($ord=0; $ord -lt $codeIdx.Count; $ord++){
  $idx = $codeIdx[$ord]
  $cell = $nb.cells[$idx]
  $lines = @($cell.source)

  if($ord -eq 0){
    $new = @()
    $new += "# Команда для установки нужных библиотек в окружение (оставлена закомментированной, запускайте при необходимости).`n"
    $new += "# Устанавливаются: mlagents, stable-baselines3, gymnasium, PyTorch с CUDA 11.8 и torchvision совместимой версии.`n"
    $new += "# Флаг -f указывает индекс колёс PyTorch с нужной сборкой.`n"
    $new += $lines
    $cell.source = $new
    continue
  }

  if($ord -eq 1){
    $new = New-Object System.Collections.Generic.List[object]
    $importComments = @(
      "# Импорт стандартного модуля для работы с путями и окружением`n",
      "# Импорт NumPy для работы с массивами и численными операциями`n",
      "# Импорт PyTorch — основной фреймворк для нейросети и вычислений на GPU`n",
      "# Импорт базового модуля нейросетей PyTorch (слои, функции активации и т.д.)`n",
      "# Импорт Python API для Unity ML-Agents (класс для управления окружением)`n",
      "# Импорт канала конфигурации движка Unity (настройка скорости, качества и пр.)`n",
      "# Импорт контейнера действий (непрерывных/дискретных) для передачи в Unity`n",
      "# Импорт алгоритма PPO из Stable-Baselines3`n",
      "# Импорт базового экстрактора признаков для пользовательской архитектуры policy/value`n",
      "# Импорт утилиты проверки совместимости окружения с Gym API`n",
      "# Импорт Gymnasium — интерфейс окружения, совместимый со Stable-Baselines3`n",
      "# Импорт наборов пространств (Box, Discrete) для описания наблюдений/действий`n"
    )
    $impI = 0
    foreach($l in $lines){
      if(($l.Trim().StartsWith('#')) -and ($l -match "[\u0400-\u04FF]" -and $l -like '*����*')){
        $new.Add("# Импорт библиотек и утилит`n")
        continue
      }
      if($impI -lt $importComments.Count -and ($l.StartsWith('import') -or $l.StartsWith('from'))){
        $new.Add($importComments[$impI]); $impI++
      }
      if($l.StartsWith('def close_unity_env')){ $new.Add("# Объявление вспомогательной функции для корректного закрытия Unity-окружения и процессов`n") }
      $new.Add($l)
    }
    $new = Insert-Above $new 'env_path' "# Абсолютный путь к скомпилированному Unity-окружению (измените при переносе проекта)`n"
    $new = Insert-Above $new 'engine_channel = EngineConfigurationChannel()' "# Создаём канал конфигурации движка Unity для ускорения симуляции и снижения качества рендера`n"
    $new = Insert-Above $new 'engine_channel.set_configuration_parameters' "# Увеличиваем скорость симуляции (time_scale) и ставим минимальное качество (quality_level=0)`n"
    $new = Insert-Above $new 'try:' "# Инициализация окружения Unity с параметрами`n"
    $new = Insert-Above $new 'env = UnityEnvironment' "# Создаём окружение: путь, worker_id, порт, side channels, таймаут`n"
    $new = Insert-Above $new 'env.reset()' "# Сбрасываем окружение, чтобы получить начальное состояние`n"
    $new = Insert-Above $new 'except Exception as e:' "# Если инициализация не удалась — печать ошибки и очистка`n"
    $new = Insert-Above $new 'if len(env.behavior_specs)' "# Проверяем, что в окружении есть хотя бы одно поведение (behavior)`n"
    $new = Insert-Above $new 'behavior_name =' "# Берём имя первого поведения`n"
    $new = Insert-Above $new "print(f'Behavior Name:" "# Печатаем имя поведения (для отладки)`n"
    $new = Insert-Above $new 'spec =' "# Получаем спецификацию поведения`n"
    $new = Insert-Above $new "print(f'Observation size:" "# Выводим размеры наблюдений`n"
    $new = Insert-Above $new "print(f'Continuous action size:" "# Выводим размер непрерывных действий`n"
    $new = Insert-Above $new "print(f'Discrete action branches:" "# Выводим структуру дискретных ветвей (если есть)`n"
    $cell.source = $new
    continue
  }

  if($ord -eq 2){
    $new = New-Object System.Collections.Generic.List[object]
    foreach($l in $lines){
      if($l.StartsWith('class CustomActorCriticNet')){ $new.Add("# Определяем пользовательский экстрактор признаков для политики/критика SB3`n") }
      if($l.Trim().StartsWith('def __init__')){ $new.Add("# Конструктор принимает пространство наблюдений и размер выходных признаков`n") }
      if($l -like '*super(CustomActorCriticNet*'){ $new.Add("# Инициализация базового класса SB3`n") }
      if($l -like '*self.fc1*'){ $new.Add("# Полносвязный слой: вход — размер наблюдения, выход — 128 (на выбранном устройстве)`n") }
      if($l -like '*self.fc2*'){ $new.Add("# Второй полносвязный слой: 128 -> 64 (на выбранном устройстве)`n") }
      if($l -like '*self.fc3*'){ $new.Add("# Третий полносвязный слой: 64 -> features_dim`n") }
      if($l -like '*self.relu*'){ $new.Add("# Функция активации ReLU`n") }
      if($l.Trim().StartsWith('def forward')){ $new.Add("# Прямой проход: последовательно применяем слои и активации`n") }
      if($l -like '*self.fc1(x)*'){ $new.Add("# Признаки после первого слоя и ReLU`n") }
      if($l -like '*self.fc2(x)*'){ $new.Add("# Признаки после второго слоя и ReLU`n") }
      if($l -like '*x = self.fc3(x)*'){ $new.Add("# Итоговые признаки после третьего слоя`n") }
      if($l.StartsWith('policy_kwargs')){ $new.Add("# Аргументы для политики PPO: экстрактор признаков и архитектура голов`n") }
      if($l -like '*features_extractor_class*'){ $new.Add("# Указываем пользовательский класс экстрактора признаков`n") }
      if($l -like '*features_extractor_kwargs*'){ $new.Add("# Параметры для конструктора экстрактора (размер выходных признаков)`n") }
      if($l -like '*net_arch*'){ $new.Add("# Архитектура policy (pi) и value (vf): два слоя 64 и 32`n") }
      $new.Add($l)
    }
    $cell.source = $new
    continue
  }

  if($ord -eq 3){
    $new = New-Object System.Collections.Generic.List[object]
    foreach($l in $lines){
      if($l.StartsWith('class UnityGymWrapper')){ $new.Add("# Обёртка Unity ML-Agents под интерфейс Gymnasium`n") }
      if($l.Trim().StartsWith('def __init__')){ $new.Add("# Конструктор получает UnityEnvironment, имя поведения и спецификацию`n") }
      if($l -like '*super(UnityGymWrapper*'){ $new.Add("# Инициализация базового класса Gym.Env`n") }
      if($l -like '*self.env =*'){ $new.Add("# Сохраняем ссылку на Unity-окружение`n") }
      if($l -like '*self.behavior_name*'){ $new.Add("# Имя поведения для обмена данными шагов`n") }
      if($l -like '*self.spec =*'){ $new.Add("# Спецификация поведения (размеры obs/action)`n") }
      if($l -like '*self.observation_space*'){ $new.Add("# Пространство наблюдений: непрерывный вектор float32`n") }
      if($l -like '*self.action_space*'){ $new.Add("# Пространство действий: непрерывное, диапазон [-1,1]`n") }
      if($l.Trim().StartsWith('def reset')){ $new.Add("# Сброс окружения по API Gymnasium: возвращаем (obs, info)`n") }
      if($l -like '*self.env.reset()*'){ $new.Add("# Сбрасываем Unity-окружение`n") }
      if($l -like '*get_steps(self.behavior_name)*' -and $l -like '*decision_steps,*'){ $new.Add("# Получаем текущие шаги решающих состояний`n") }
      if($l -like '*obs = decision_steps.obs*'){ $new.Add("# Берём первое наблюдение первого агента`n") }
      if($l.Trim().StartsWith('def step')){ $new.Add("# Один шаг среды по API Gymnasium`n") }
      if($l -like '*action = np.array*'){ $new.Add("# Гарантируем форму действия (1, размер_действия)`n") }
      if($l -like '*ActionTuple()*'){ $new.Add("# Создаём контейнер действий Unity`n") }
      if($l -like '*add_continuous*'){ $new.Add("# Добавляем непрерывные действия`n") }
      if($l -like '*set_actions*'){ $new.Add("# Передаём действия агенту`n") }
      if($l -like '*self.env.step()*'){ $new.Add("# Продвигаем симуляцию на один шаг`n") }
      if($l -like '*decision_steps, terminal_steps*'){ $new.Add("# Считываем решения и терминальные шаги`n") }
      if($l -like '*done =*'){ $new.Add("# Флаг завершения эпизода`n") }
      if($l -like '*terminal_steps.reward*'){ $new.Add("# Награда и наблюдение при завершении эпизода`n") }
      if($l -like '*decision_steps.reward*'){ $new.Add("# Награда и наблюдение при продолжающемся эпизоде`n") }
      if($l -like '*truncated = False*'){ $new.Add("# Усечение не используется — False`n") }
      if($l.Trim().StartsWith('def close')){ $new.Add("# Закрытие окружения с помощью вспомогательной функции`n") }
      $new.Add($l)
    }
    $cell.source = $new
    continue
  }

  if($ord -eq 4){
    $new = New-Object System.Collections.Generic.List[object]
    foreach($l in $lines){
      if($l.Trim().StartsWith('try:')){ $new.Add("# Обучение модели PPO на выбранном устройстве`n") }
      if($l -like '*device =*'){ $new.Add("# Определяем устройство: 'cuda' если доступно, иначе 'cpu'`n") }
      if($l.Trim().StartsWith('model = PPO(')){ $new.Add("# Создаём и настраиваем модель PPO из SB3`n") }
      if($l -like "*'MlpPolicy'*"){ $new.Add("# Используем MLP-политику`n") }
      if($l -like '*policy_kwargs*'){ $new.Add("# Передаём пользовательский экстрактор и архитектуру голов`n") }
      if($l -like '*learning_rate*'){ $new.Add("# Скорость обучения Adam`n") }
      if($l -like '*n_steps*' -and $l -notlike '*model.learn*'){ $new.Add("# Количество шагов в буфере до обновления`n") }
      if($l -like '*batch_size*'){ $new.Add("# Размер мини-батча`n") }
      if($l -like '*n_epochs*'){ $new.Add("# Число эпох прохода по буферу`n") }
      if($l -like '*gamma*'){ $new.Add("# Коэффициент дисконтирования`n") }
      if($l -like '*gae_lambda*'){ $new.Add("# Параметр GAE`n") }
      if($l -like '*clip_range*'){ $new.Add("# Порог обрезки PPO`n") }
      if($l -like '*ent_coef*'){ $new.Add("# Энтропийная регуляризация`n") }
      if($l -like '*verbose*'){ $new.Add("# Уровень логгирования`n") }
      if($l -like '*device=*'){ $new.Add("# Устройство вычислений (GPU/CPU)`n") }
      if($l -like '*model.learn*'){ $new.Add("# Запускаем процесс обучения`n") }
      if($l -like "*model.save('ppo_myagent_gpu')*"){ $new.Add("# Сохраняем обученную модель`n") }
      if($l -like "*if device == 'cuda':*"){ $new.Add("# Если используется CUDA — выводим информацию о GPU`n") }
      if($l -like '*torch.cuda.get_device_name*'){ $new.Add("# Название видеокарты`n") }
      if($l -like '*torch.cuda.get_device_properties*'){ $new.Add("# Объем памяти GPU в ГБ`n") }
      if($l.Trim().StartsWith('except Exception as e:')){ $new.Add("# Обработка ошибок обучения`n") }
      if($l.Trim().StartsWith('finally:')){ $new.Add("# В любом случае закрываем окружение`n") }
      $new.Add($l)
    }
    $cell.source = $new
    continue
  }

  if($ord -eq 5){
    $new = New-Object System.Collections.Generic.List[object]
    foreach($l in $lines){
      if($l.Trim() -eq 'import torch'){ $new.Add("# Импорт PyTorch (на случай изолированного запуска ячейки)`n") }
      if($l -like '*from torch.nn import Parameter*'){ $new.Add("# Импорт Parameter для хранения констант в модуле`n") }
      if($l.Trim().StartsWith('class WrapperNet')){ $new.Add("# Обёртка над политикой для экспорта в ONNX/Unity Sentis`n") }
      if($l.Trim().StartsWith('def __init__')){ $new.Add("# Принимает политику SB3 и размер непрерывного действия`n") }
      if($l -like '*self.policy = policy*'){ $new.Add("# Сохраняем ссылку на политику`n") }
      if($l -like '*version_number = *' -and $l -notlike '*Parameter*'){ $new.Add("# Версия формата (MLAgents2_0 = 3)`n") }
      if($l -like '*self.version_number*'){ $new.Add("# Регистрируем как неизменяемый параметр`n") }
      if($l -like '*memory_size = *' -and $l -notlike '*Parameter*'){ $new.Add("# Размер памяти RNN = 0 (RNN не используется)`n") }
      if($l -like '*self.memory_size*'){ $new.Add("# Регистрируем память как константу`n") }
      if($l -like '*continuous_shape = *' -and $l -notlike '*Parameter*'){ $new.Add("# Форма выхода непрерывных действий`n") }
      if($l -like '*self.continuous_shape*'){ $new.Add("# Регистрируем форму как константу`n") }
      if($l.Trim().StartsWith('def forward')){ $new.Add("# Прямой проход: возвращаем действия и служебные тензоры`n") }
      if($l -like '*self.policy(obs, deterministic=True)[0]*'){ $new.Add("# Получаем детерминированные действия из политики`n") }
      if($l -like '*torch.mul(continuous_actions, mask)*'){ $new.Add("# Применяем маску действий (элементное умножение)`n") }
      if($l.Trim().StartsWith('try:')){ $new.Add("# Экспорт модели в ONNX с обработкой ошибок`n") }
      if($l -like '*policy = model.policy.to(device)*'){ $new.Add("# Переносим политику на нужное устройство`n") }
      if($l -like '*continuous_action_size = *'){ $new.Add("# Получаем размер непрерывного действия из спецификации`n") }
      if($l -like '*wrapper_net = WrapperNet*'){ $new.Add("# Создаём обёртку для экспорта`n") }
      if($l -like '*dummy_input*'){ $new.Add("# Заглушка входа: случайное наблюдение формы [1, obs_size]`n") }
      if($l -like '*dummy_mask*'){ $new.Add("# Заглушка маски действий: все действия доступны`n") }
      if($l -like '*torch.onnx.export(*'){ $new.Add("# Экспорт в ONNX: задаём имена входов/выходов и динамические оси`n") }
      if($l -like '*opset_version=*'){ $new.Add("# Версия опсета ONNX, совместимая с Unity Sentis`n") }
      if($l -like "*trained_myagent.onnx*" -and $l -like '*print(*'){ $new.Add("# Сообщение об успешном экспорте и проверка наличия файла`n") }
      if($l.Trim().StartsWith('except Exception as e:')){ $new.Add("# Обработка ошибок экспорта: совет сменить opset при проблемах`n") }
      if($l.Trim().StartsWith('finally:')){ $new.Add("# Закрываем окружение в любом случае`n") }
      $new.Add($l)
    }
    $cell.source = $new
    continue
  }

  if($ord -eq 6){
    $new = New-Object System.Collections.Generic.List[object]
    foreach($l in $lines){
      if($l.Trim().StartsWith('try:')){ $new.Add("# Тестовое выполнение модели в окружении`n") }
      if($l -like '*obs, _ = gym_env.reset()*'){ $new.Add("# Сбрасываем окружение и получаем начальное наблюдение`n") }
      if($l -like '*for _ in range(1000):*'){ $new.Add("# Выполняем до 1000 шагов`n") }
      if($l -like '*model.predict*'){ $new.Add("# Предсказываем действие по наблюдению (детерминированно)`n") }
      if($l -like '*gym_env.step*'){ $new.Add("# Делаем шаг в среде`n") }
      if($l -like '*if done or truncated*'){ $new.Add("# Если эпизод завершён/усечён — начинаем заново`n") }
      if($l.Trim().StartsWith('except Exception as e:')){ $new.Add("# Обработка ошибок тестирования`n") }
      if($l.Trim().StartsWith('finally:')){ $new.Add("# Закрываем окружение в любом случае`n") }
      $new.Add($l)
    }
    $cell.source = $new
    continue
  }
}

$json = $nb | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($nbPath, $json, [System.Text.Encoding]::UTF8)
Write-Host 'OK'
