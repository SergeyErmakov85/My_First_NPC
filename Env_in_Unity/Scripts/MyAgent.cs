using UnityEngine;
using Unity.MLAgents;
using Unity.MLAgents.Sensors;
using Unity.MLAgents.Actuators;


public class MyAgent : Agent
{
    public Transform Target; // Цель, к которой движется агент
    public float boundary = 50f; // Границы среды
    private Rigidbody rBody; // Компонент для физики

    void Start()
    {
        rBody = GetComponent<Rigidbody>(); // Инициализируем Rigidbody
    }

    public override void CollectObservations(VectorSensor sensor)
    {
        // 6 наблюдений: нормализованные значения
        sensor.AddObservation(transform.localPosition.x / boundary); // x агента
        sensor.AddObservation(transform.localPosition.z / boundary); // z агента
        sensor.AddObservation(Target.localPosition.x / boundary);    // x цели
        sensor.AddObservation(Target.localPosition.z / boundary);    // z цели
        sensor.AddObservation(rBody.linearVelocity.x / 10f);              // скорость x
        sensor.AddObservation(rBody.linearVelocity.z / 10f);              // скорость z
    }

    public override void OnActionReceived(ActionBuffers actions)
    {
        // Принимаем 2 непрерывных действия: движение по X и Z
        float moveX = actions.ContinuousActions[0]; // -1 to 1
        float moveZ = actions.ContinuousActions[1]; // -1 to 1

        // Уменьшаем силу для медленного движения
        Vector3 controlSignal = new Vector3(moveX, 0f, moveZ);
        rBody.AddForce(controlSignal * 5f); // Снижаем с 10f до 5f

        // Расстояние до цели
        float distanceToTarget = Vector3.Distance(transform.localPosition, Target.localPosition);

        // Награды с увеличенным порогом для цели
        if (distanceToTarget < 3.0f) // Увеличиваем с 1.42f до 3.0f
        {
            AddReward(1.0f); // Положительная награда
            EndEpisode();    // Завершаем эпизод
            Debug.Log("Эпизод завершён: достигнута цель!");
        }
        else
        {
            AddReward(0.01f / distanceToTarget); // Награда за приближение
        }

        // Проверка границ с буфером
        if (Mathf.Abs(transform.localPosition.x) > boundary + 5f || Mathf.Abs(transform.localPosition.z) > boundary + 5f)
        {
            AddReward(-1.0f); // Штраф за выход
            EndEpisode();     // Завершаем эпизод
            Debug.Log("Эпизод завершён: выход за границы!");
        }

        // Логи для отладки
        Debug.Log($"Actions: MoveX={moveX}, MoveZ={moveZ}, Distance={distanceToTarget}, Reward={GetCumulativeReward()}");
    }

    public override void OnEpisodeBegin()
    {
        // Сброс позиции и скорости
        transform.localPosition = new Vector3(0, 0.5f, 0);
        rBody.linearVelocity = Vector3.zero;
        rBody.angularVelocity = Vector3.zero;
        Target.localPosition = new Vector3(Random.Range(-boundary, boundary), 0.5f, Random.Range(-boundary, boundary));
    }

    public override void Heuristic(in ActionBuffers actionsOut)
    {
        // Ручное управление для тестирования
        var continuousActions = actionsOut.ContinuousActions;
        continuousActions[0] = Input.GetAxisRaw("Horizontal"); // Стрелки влево/вправо
        continuousActions[1] = Input.GetAxisRaw("Vertical");   // Стрелки вверх/вниз
    }
}