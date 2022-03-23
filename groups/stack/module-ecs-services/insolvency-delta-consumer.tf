
resource "aws_ecs_service" "insolvency-delta-consumer-ecs-service" {
  name            = "${var.environment}-insolvency-delta-consumer"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.insolvency-delta-consumer-task-definition.arn
  desired_count   = var.insolvency_delta_consumer_desired_count
}

locals {
  insolvency-delta-consumer-definition = merge(
    {
      environment                       : var.environment
      name_prefix                       : var.name_prefix
      aws_region                        : var.aws_region
      external_top_level_domain         : var.external_top_level_domain
      docker_registry                   : var.docker_registry
      log_level                         : var.log_level
      insolvency_delta_consumer_release_version : var.insolvency_delta_consumer_release_version
      chs_kafka_api_url                 : var.chs_kafka_api_url
      kafka_broker_address              : var.kafka_broker_address
      kafka_consumer_topic              : var.kafka_consumer_topic
      kafka_consumer_timeout_ms         : var.kafka_consumer_timeout_ms
      kafka_consumer_sleep_ms           : var.kafka_consumer_sleep_ms
    },
      var.secrets_arn_map
  )
}

resource "aws_ecs_task_definition" "insolvency-delta-consumer-task-definition" {
  family             = "${var.environment}-insolvency-delta-consumer"
  execution_role_arn = var.task_execution_role_arn
  container_definitions = templatefile(
    "${path.module}/insolvency-delta-consumer-definition.tmpl", local.insolvency-delta-consumer-definition
  )
}
