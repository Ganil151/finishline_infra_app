#========================================================================
#                      *** JUMPHOST Locals Configuration ***
#========================================================================
locals {
   tags= merge(var.common_tags, {
     Name = "${var.project_name}-${var.environment}-jumphost"
     Environment = var.environment
     ManagedBy = var.managed_by
     Module = "jumphost"
   }) 
}n