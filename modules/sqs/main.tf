resource "aws_sqs_queue" "queue" {
  name = var.queue_name

  tags = {
    Name = var.queue_name
  }
}
