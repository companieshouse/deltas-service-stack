locals {
  service_name = "insolvency-data-api"
  # what is this port? ??
  ida_proxy_port = 11000 # local port number defined for proxy target of tdg service sitting behind eric - 
}

resource "aws_ecs_service" "insolvency-data-api-ecs-service" {
  name            = "${var.environment}-${local.service_name}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.insolvency-data-api-task-definition.arn
  desired_count   = 1
  depends_on      = [var.data-sync-lb-arn]
  load_balancer {
    target_group_arn = aws_lb_target_group.insolvency-data-api-target_group.arn
    container_port   = var.tdg_application_port
    container_name   = "eric" # [ALB -> target group -> eric -> tdg] so eric container named here
  }
}

locals {
  definition = merge(
    {
      service_name               : local.service_name
      environment                : var.environment
      name_prefix                : var.name_prefix
      aws_region                 : var.aws_region
      external_top_level_domain  : var.external_top_level_domain
      account_subdomain_prefix   : var.account_subdomain_prefix
      log_level                  : var.log_level
      docker_registry            : var.docker_registry

      # eric specific configs
      eric_port                      : var.tdg_application_port # eric needs to be the first servic ein the chain from ALB
      eric_version                   : var.eric_version
      eric_cache_url                 : var.eric_cache_url
      eric_cache_max_connections     : var.eric_cache_max_connections
      eric_cache_max_idle            : var.eric_cache_max_idle
      eric_cache_idle_timeout        : var.eric_cache_idle_timeout
      eric_cache_ttl                 : var.eric_cache_ttl
      eric_flush_interval            : var.eric_flush_interval
      eric_graceful_shutdown_period  : var.eric_graceful_shutdown_period
      eric_default_rate_limit        : var.eric_default_rate_limit
      eric_default_rate_limit_window : var.eric_default_rate_limit_window

      # insolvency data api specific configs
      insolvency_data_api_release_version        : var.insolvency_data_api_release_version
      ida_proxy_port             : local.ida_proxy_port
    },
      var.secrets_arn_map
  )
}

resource "aws_ecs_task_definition" "insolvency-data-api-task-definition" {
  family                = "${var.environment}-${local.service_name}"
  execution_role_arn    = var.task_execution_role_arn
  container_definitions = templatefile(
    "${path.module}/${local.service_name}-task-definition.tmpl", local.definition
  )
}

resource "aws_lb_target_group" "insolvency-data-api-target_group" {
  name     = "${var.environment}-${local.service_name}"
  port     = var.ida_application_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    interval            = "30"
    matcher             = "200"
    path                = "/insolvency-data-api/healthcheck"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = "5"
  }
}

resource "aws_lb_listener_rule" "insolvency-data-api" {
  listener_arn = var.data-sync-lb-listener-arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.insolvency-data-api-target_group.arn
  }
  condition {
    field  = "path-pattern"
    values = ["/company/(.*)/insolvency.*"]
  }
}
