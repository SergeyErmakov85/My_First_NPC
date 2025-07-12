// MyAgent.cs  // Имя файла скрипта
// 27.06.2025 AI-Tag  // Дата создания и пометка AI
// This was created with the help of Assistant, a Unity Artificial Intelligence product.  // Информация об инструменте, использованном для создания
// MyAgent.cs  // Имя файла скрипта
// This script defines a simple agent that can move around in a Unity environment, collect observations,  // Краткое описание скрипта
// and interact with objects (yellow and blue balls). The agent receives rewards for touching the yellow ball  // Продолжение описания скрипта
// and penalties for touching blue balls. It uses continuous actions for movement and can be controlled  // Продолжение описания скрипта
// via keyboard for debugging purposes.  // Завершение описания скрипта
// Ensure you have the ML-Agents package installed in your Unity project to use this script.  // Условие для корректной работы скрипта

using UnityEngine;                       // Подключаем библиотеку UnityEngine для работы с игровыми объектами и компонентами
using Unity.MLAgents;                    // Подключаем библиотеку ML-Agents для создания и настройки агентов
using Unity.MLAgents.Actuators;          // Подключаем функционал для управления действиями агента
using Unity.MLAgents.Sensors;            // Подключаем функционал для сбора наблюдений

public class MyAgent : Agent            // Объявляем класс MyAgent, наследующийся от базового класса Agent
{
    public Transform yellowBall;         // Поле: ссылка на объект желтого шарика в сцене
    public Transform[] blueBalls;        // Поле: массив ссылок на объекты синих шариков в сцене

    private Rigidbody agentRigidbody;    // Приватное поле: ссылка на компонент Rigidbody агента

    public float moveSpeed = 5f;         // Публичное поле: скорость движения агента

    public override void Initialize()   // Метод вызывается один раз при старте (инициализация агента)
    {
        agentRigidbody = GetComponent<Rigidbody>();  // Получаем и сохраняем компонент Rigidbody, прикрепленный к агенту
    }

    public override void OnEpisodeBegin()  // Метод вызывается в начале каждого эпизода обучения
    {
        // Сбрасываем положение агента на случайную точку в пределах области
        transform.localPosition = new Vector3(Random.Range(-4f, 4f), 0.5f, Random.Range(-4f, 4f));  
        agentRigidbody.linearVelocity = Vector3.zero;       // Обнуляем линейную скорость агента
        agentRigidbody.angularVelocity = Vector3.zero; // Обнуляем угловую скорость агента

        // Сбрасываем положение желтого шарика на случайную точку в пределах области
        yellowBall.localPosition = new Vector3(Random.Range(-4f, 4f), 0.5f, Random.Range(-4f, 4f));  

        // Сбрасываем положение каждого синего шарика на случайную точку
        foreach (Transform blueBall in blueBalls)  
        {
            blueBall.localPosition = new Vector3(Random.Range(-4f, 4f), 0.5f, Random.Range(-4f, 4f));  
        }
    }

    public override void CollectObservations(VectorSensor sensor)  // Метод сбора наблюдений об окружении
    {
        // Добавляем в наблюдения текущую позицию агента
        sensor.AddObservation(transform.localPosition);  

        // Добавляем в наблюдения позицию желтого шарика
        sensor.AddObservation(yellowBall.localPosition);  

        // Добавляем в наблюдения позиции всех синих шариков
        foreach (Transform blueBall in blueBalls)  
        {
            sensor.AddObservation(blueBall.localPosition);  
        }
    }

    public override void OnActionReceived(ActionBuffers actions)  // Метод обработки действий, сгенерированных моделью
    {
        // Считываем значения действий по осям X и Z из массива непрерывных действий
        float moveX = actions.ContinuousActions[0];  
        float moveZ = actions.ContinuousActions[1];  

        // Создаем вектор движения и умножаем его на скорость и дельту времени
        Vector3 move = new Vector3(moveX, 0, moveZ) * moveSpeed * Time.deltaTime;  
        // Применяем силу к Rigidbody агента, чтобы переместить его
        agentRigidbody.AddForce(move, ForceMode.VelocityChange);  
    }

    public override void Heuristic(in ActionBuffers actionsOut)  // Метод для ручного управления (отладка)
    {
        var continuousActions = actionsOut.ContinuousActions;  
        continuousActions[0] = Input.GetAxis("Horizontal");  // Назначаем ось Horizontal на первое действие
        continuousActions[1] = Input.GetAxis("Vertical");    // Назначаем ось Vertical на второе действие
    }

    private void OnTriggerEnter(Collider other)  // Метод вызывается при столкновении с триггером
    {
        if (other.transform == yellowBall)  // Если коснулись желтого шарика
        {
            SetReward(1f);    // Выдаем награду +1
            EndEpisode();     // Завершаем эпизод
        }
        else  // Иначе проверяем, не синий ли шарик вызвал столкновение
        {
            foreach (Transform blueBall in blueBalls)  
            {
                if (other.transform == blueBall)  // Если коснулись синего шарика
                {
                    SetReward(-1f);   // Выдаем штраф -1
                    EndEpisode();     // Завершаем эпизод
                    break;            // Прерываем цикл, так как уже нашли синий шарик
                }
            }
        }
    }
}