provider "aws"{
region = "ap-south-1"
profile = "default"
}

//CREATE A SECURITY_GROUP

variable "ami_id"{
type = string
default = "ami-0447a12f28fddb066"
}


variable "ami_type"{
type = string
default = "t2.micro"
}

resource "aws_security_group" "http" {
  name        = "Security"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Tera_Security"
  }
}

// CREATE A KEY_PAIR

resource "tls_private_key" "dha_key" {
  algorithm   = "RSA"
}


resource "aws_key_pair" "test_key"{
  key_name   = "tera-key"
  public_key = "${tls_private_key.dha_key.public_key_openssh}"

	depends_on =[
	tls_private_key.dha_key
]
}

resource "local_file" "key_file"{
	content ="${tls_private_key.dha_key.private_key_pem}"
	filename = "tera-key.pem"

	depends_on = [
	tls_private_key.dha_key
]
}

// CREATE A INSTANCE

resource "aws_instance" "OS1"{
  ami             = "${var.ami_id}"
  instance_type   = "${var.ami_type}"
  key_name        = "${aws_key_pair.test_key.key_name}"
  security_groups = ["${aws_security_group.http.name}"]

// PROVIDE CONNECTION USING SSH REMOTE LOGIN

provisioner "remote-exec"{
      connection {
      agent       = "false"
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${tls_private_key.dha_key.private_key_pem}"
      host        = "${aws_instance.OS1.public_ip}"
   }
 
      inline = [

      "sudo yum install httpd git html -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
    ]
}
		tags ={
		Name = "dhanrajos"
}
}

//CREATE A VOLUME

resource "aws_ebs_volume" "ebs_vol"{
  availability_zone = aws_instance.OS1.availability_zone
  size              = 1
  tags = {
    Name = "Pendrive"
  }
}

//ATTACH VOLUME WITH INSTANCE

resource "aws_volume_attachment" "ebs_att"{
  device_name = "/dev/sdf"
  volume_id   = "${aws_ebs_volume.ebs_vol.id}"
  instance_id = "${aws_instance.OS1.id}"
  force_detach = true
}


resource "null_resource" "null"{
	provisioner "local-exec"{
	command= "echo ${aws_instance.OS1.public_ip} > publicip.txt"
	}
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.dha_key.private_key_pem}"
    host     = aws_instance.OS1.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdf",
      "sudo mount  /dev/xvdf  /var/www/html/",
      "sudo rm -rf /var/www/html/",
      "sudo git clone https://github.com/DhanrajSolanki/Terraform.git /var/www/html/"
    ]
  }
}

resource "aws_s3_bucket" "dhanraj1234"{
  bucket = "web-tera-bucket"
  acl    = "public-read"
	
	tags ={
		Name ="bucket1"
	}
	
	versioning{
		enabled = true
	}
}

resource "aws_s3_bucket_object" "object1"{

	depends_on = [
		aws_s3_bucket.dhanraj1234,
	]
  bucket = "${aws_s3_bucket.dhanraj1234.bucket}"
  key = "Dog.jpg"
  source = "C:/Users/PCD/Desktop/Test/Dog.jpg"
  acl = "public-read"
  content_type= "images or jpg"
}	


resource "aws_cloudfront_distribution" "cfd"{
  origin {
    domain_name = "${aws_s3_bucket.dhanraj1234.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.dhanraj1234.id}"
  }
 	
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "s3 Distribution"
  default_root_object ="tera.html"

	logging_config{
	include_cookies =false
	bucket = "web-tera-bucket.s3.amazonaws.com"
	prefix = "myprefix"
	}



default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.dhanraj1234.id}"


forwarded_values {
      query_string = false




      cookies {
        forward = "none"
      }
    }



viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

# Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${aws_s3_bucket.dhanraj1234.id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.dhanraj1234.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"


restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }


tags = {
    Name        = "CloudFront-Distribution-Tera"
    Environment = "Production"
  }


viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "my_ip"{
		value = aws_instance.OS1.public_ip
}