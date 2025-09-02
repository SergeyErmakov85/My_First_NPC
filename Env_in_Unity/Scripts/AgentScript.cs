using UnityEngine;
using Unity.MLAgents;
using Unity.MLAgents.Actuators;
using Unity.MLAgents.Sensors;

public class AgentScript : Agent
{
    public Transform targetCube;
    private Rigidbody rb;
    [Tooltip("Multiplier for agent movement force")]
    public float moveForce = 10f;

    void Start()
    {
        rb = GetComponent<Rigidbody>();
    }

    public override void OnEpisodeBegin()
    {
        // Randomize cube position within plane bounds
        float xPos = Random.Range(-4.0f, 4.0f);
        float zPos = Random.Range(-4.0f, 4.0f);
        targetCube.position = new Vector3(xPos, 0.5f, zPos);

        // Reset sphere position to center
        transform.position = new Vector3(0, 0.5f, 0);
        rb.linearVelocity = Vector3.zero;
        rb.angularVelocity = Vector3.zero;
    }

    public override void CollectObservations(VectorSensor sensor)
    {
        // Observe agent's position and target cube's position
        sensor.AddObservation(transform.position);
        sensor.AddObservation(targetCube.position);
    }

    public override void OnActionReceived(ActionBuffers actions)
    {
        // Actions: x, z movement
        Vector3 move = new Vector3(actions.ContinuousActions[0], 0, actions.ContinuousActions[1]);

        rb.AddForce(move * moveForce);

        // Reward for moving towards cube
        float distanceToTarget = Vector3.Distance(transform.position, targetCube.position);

        // Завершение эпизода при достижении цели
        if (distanceToTarget < 0.5f)
        {
            AddReward(1.0f);
            EndEpisode();
            return;
        }

        // Option 1: Reduce penalty coefficient
        AddReward(-0.001f * distanceToTarget);

        // Option 2 (alternative): Only penalize if not getting closer (uncomment to use)
        // if (distanceToTarget > previousDistance)
        // {
        //     AddReward(-0.01f);
        // }
        // previousDistance = distanceToTarget;

        // Penalty for falling off plane
        if (transform.position.y < 0.1f)
        {
            AddReward(-1.0f);
            EndEpisode();
            return;
        }

        if (transform.position.y < 0)
        {
            AddReward(-1.0f);
            EndEpisode();
        }
    }

    /// <summary>
    /// Provides manual input for testing the agent using keyboard controls.
    /// </summary>
    public override void Heuristic(in ActionBuffers actionsOut)
    {
        var continuousActionsOut = actionsOut.ContinuousActions;
        continuousActionsOut[0] = Input.GetAxis("Horizontal");
        continuousActionsOut[1] = Input.GetAxis("Vertical");
    }
}