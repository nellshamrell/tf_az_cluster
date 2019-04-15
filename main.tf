provider "azurerm" {
 version = "=1.24.0" 
}


resource "azurerm_resource_group" "nelltfgroup" {
  name = "nellresourcegroup"    
  location = "eastus"

  tags {
      environment = "Nell TF Demo"
  }
}

resource "azurerm_virtual_network" "nelltfnetwork" {
    name = "NellNet"
    address_space = ["10.0.0.0/16"]
    location = "eastus"
    resource_group_name = "${azurerm_resource_group.nelltfgroup.name}"
}

resource "azurerm_subnet" "nelltfsubnet" {
    name = "NellSubNet"
    resource_group_name = "${azurerm_resource_group.nelltfgroup.name}"
    virtual_network_name = "${azurerm_virtual_network.nelltfnetwork.name}"
    address_prefix = "10.0.2.0/24"
}

resource "azurerm_public_ip" "nelltfpublicip" {
    name = "NellIP"
    location = "eastus"
    resource_group_name = "${azurerm_resource_group.nelltfgroup.name}"
    allocation_method = "Dynamic"

    tags {
        environment = "Nell TF Demo"
    }
}

resource "azurerm_lb" "nelllb" {
    name = "NellLB"
    location = "eastus" 
    resource_group_name = "${azurerm_resource_group.nelltfgroup.name}"

    frontend_ip_configuration {
        name = "PublicIPAddress"
        public_ip_address_id = "${data.azurerm_public_ip.nelltfpublicip.id}"
        
    } 
}

resource "azurerm_lb_backend_address_pool" "nelllb" {
    resource_group_name = "${azurerm_resource_group.nelltfgroup.name}"
    loadbalancer_id = "${azurerm_lb.nelllb.id}"
    name = "BackEndAddressPool"
}

resource "azurerm_network_security_group" "nelltfsg" {
    name = "NellSecurityGroup"
    location = "eastus"
    resource_group_name = "${azurerm_resource_group.nelltfgroup.name}"
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags {
        environment = "Nell TF Demo"
    }
}

resource "azurerm_network_interface" "nellnetworkinterface" {
    name = "nellNIC"
    location = "eastus"
    resource_group_name = "${azurerm_resource_group.nelltfgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.nelltfsg.id}"
    ip_configuration {
        name = "nellNetworkInterface"
        subnet_id = "${azurerm_subnet.nelltfsubnet.id}"
        private_ip_address_allocation = "Dynamic"
        load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.nelllb.id}"]
    }

    tags {
        environment = "Nell TF Demo"
    }
}

resource "random_id" "randomId" {
    keepers = {
        resource_group = "${azurerm_resource_group.nelltfgroup.name}"        
    }

    byte_length = 8
}

resource "azurerm_storage_account" "nellstorageaccount" {
    name = "diag${random_id.randomId.hex}"
    resource_group_name = "${azurerm_resource_group.nelltfgroup.name}"
    location = "eastus"
    account_replication_type = "LRS"
    account_tier = "Standard"

    tags {
        environment = "Nell TF Demo"
    }
}

resource "azurerm_virtual_machine" "nellvm" {
    name = "nellVM"
    location = "eastus" 
    resource_group_name = "${azurerm_resource_group.nelltfgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.nellnetworkinterface.id}"]
    vm_size = "Standard_DS1_v2"

    storage_os_disk {
        name = "nellOsDisk"
        caching = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer = "UbuntuServer"
        sku = "16.04.0-LTS"
        version = "latest"
    }

    os_profile = {
        computer_name = "nellvm"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCmYMd+MeEUMAacYqZrdtdyhB/JNzc58nfLaRKNb1SkPqGp2wgqTfsamLyKhfcl5oolmc8F31JGaxBuodu3ejeId1o6hgSS9cSQLJ9O8pcZKNKq2e31s0KCWopl4exdc3Cm4RM9WDD/RvaarpQqvN9udVGN56CD+yUriHyukp2lE7xEL+npbKFQwCLzkXFTToPdYu8XbDCjdKLnsNnF8T2DmaZE8AKC+B9Cbn//LHC/WdeflLxkUNyNaliXEERtLLKld9MyQcnf56MGb62RQPh36IilCW3oL8eFYhcA5SawbQeiG7hK45Kp0d03CW1WpZ/4UnL5iIFcyukF5r9c+NKI7ypM/M3HbYzo08uqSQ/SXsATf6lVp0KruUs6A95xHyL4VubN7tvy+/OW48i1X3Iwy0s5u5b0NwvALuEcZmMM9Jaq+yp9D5ghaM07GfttstqoOx8VQ0wVQR/LF0hV3EPHniDMeMi7PFPg9XVffGGVmjkUQe1C6ER857OxCa1xysKpe7thXfQQAYTLCDrQKAn3tiAdD8ecGlOxYdcVTCpfWljx19/TYk2YSBj3n4rAm6CtlhgY3THBvfbIMMN7W3O7B6TQR8e2zYMrKotNaJWYRdgI9mQuF4e4dYN6U7i0RmSKXO4gcWkxFcy/9m+c/3PzzsPTxtID5MUcOpJNzEAHJw== nellshamrell@gmail.com"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.nellstorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Nell TF Demo"
    }
}

data "azurerm_public_ip" "nelltfpublicip" {
  name                = "${azurerm_public_ip.nelltfpublicip.name}"
  resource_group_name = "${azurerm_resource_group.nelltfgroup.name}"
}

output "ip_address" {
  value = "${data.azurerm_public_ip.nelltfpublicip.ip_address}"
}