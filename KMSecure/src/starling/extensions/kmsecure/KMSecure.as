package 
{
	/*
	 * KMSECURE
	 * The MIT License (MIT)
	 * Copyright (c) 2015 Matteo Fumagalli
	 * https://github.com/kemondori/kmsecure
	*/
	import flash.geom.Point;
	import flash.utils.ByteArray;

	public class KMSecure 
	{
		private static const CRYPT_HEADER_CODE:String = "?|938ìçd%_KMS_";
		private static const CRYPT_HEADER_CODE_SIZE:int = 16;
		private static const SIZE_UINT64:int = 8;
		private static var blowfishes:Vector.<BlowFishKeyLE> = new Vector.<BlowFishKeyLE>();

		public function KMSecure() 
		{
		}
		
		public static function add_key(key:String):void
		{
			var array:ByteArray = new ByteArray();
			array.writeMultiByte(key, "utf-8");
			blowfishes.push(new BlowFishKeyLE(array));
		}
		
		public static function remove_keys(key:String):void
		{
			blowfishes = new Vector.<BlowFishKeyLE>();
		}
		
		public static function decrypt(buffer:ByteArray,key_index:int = 0):ByteArray
		{
			var cryptato:Boolean = false;
			var len8:int;
			var buffer_dest:ByteArray;
			var px1:int,px2:int,tmpsize:int,tmpsize8:int;
			var total_file_size:uint;
			var hoff:int = 68; //header size
			var header_code:String;
			var header_hard:Boolean;
			var header_version:int;
			var header_soft_point:int;
			var header_soft_perc:int;
			var header_size_buf:int;
			var i:int, k:int;
			var padder:PKCS5 = new PKCS5(SIZE_UINT64);
			
			if(blowfishes.length<=0)
			{
				throw new Error("\nMUST INITIALIZE KMSECURE WITH SETKEY\n");
			}
			else if (blowfishes.length <= key_index)
			{
				return buffer;
			}

			total_file_size = buffer.length;

			if(total_file_size > hoff)
			{
				buffer.position = 0;
				header_code = buffer.readMultiByte(CRYPT_HEADER_CODE_SIZE,"utf-8");
				buffer.position = CRYPT_HEADER_CODE_SIZE;
				header_hard = buffer.readBoolean();
				buffer.position = CRYPT_HEADER_CODE_SIZE + 1;
				header_soft_point = buffer.readUnsignedByte();
				buffer.position = CRYPT_HEADER_CODE_SIZE + 1 + 1;
				header_soft_perc = buffer.readUnsignedByte();
				//there is a compiler padding...
				buffer.position = CRYPT_HEADER_CODE_SIZE + 1 + 1 + 2;
				header_size_buf = BigToLittle(buffer.readUnsignedInt());
				buffer.position = CRYPT_HEADER_CODE_SIZE + 1 + 1 + 8;
				header_version = BigToLittle(buffer.readUnsignedInt());
				buffer.position = 0;
				cryptato = true;
				for(k=0;k<CRYPT_HEADER_CODE_SIZE;k++)
					if(header_code.charAt(k) != CRYPT_HEADER_CODE.charAt(k))
						cryptato = false;
			}
			else
				cryptato = false;

			if(cryptato == false)
				return buffer;
				
			buffer_dest = new ByteArray();
			
			if(!header_hard)
			{
				var px:Point = calc_soft_points(header_soft_point,header_soft_perc,header_size_buf);
				px1 = px.x;
				px2 = px.y;
				tmpsize = px2 - px1;
				if(tmpsize > 0)
				{
					var buffer_mid:ByteArray = new ByteArray();
					tmpsize8 = get_len8_dim(tmpsize);
					buffer_mid.writeBytes(buffer, (hoff + px1), tmpsize8);
					for (i = 0; i < tmpsize8;i+=8)
						blowfishes[key_index].decrypt(buffer_mid,  i);
					padder.unpad(buffer_mid);
					buffer_dest.writeBytes(buffer, hoff, px1);
					buffer_dest.position = px1;
					buffer_dest.writeBytes(buffer_mid, 0, buffer_mid.length);
					buffer_dest.position = px2;
					buffer_dest.writeBytes(buffer, hoff + px1 + tmpsize8, header_size_buf - px2);
					buffer_dest.position = 0;
				}
				else
				{
					return buffer;
				}
			}
			else
			{
				buffer_dest.writeBytes(buffer, hoff, buffer.length - hoff);
				for (i=0; i < buffer_dest.length;i+=8)
					blowfishes[key_index].decrypt(buffer_dest, i);
				padder.unpad(buffer_dest);
			}

			return decrypt(buffer_dest,key_index+1);
		}
		
		private static function BigToLittle(num:uint):uint
        {
			return (((num>>24)&0xff) | ((num<<8)&0xff0000) |((num>>8)&0xff00) | ((num << 24) & 0xff000000));
        }
		
		protected static function calc_soft_points(soft_point:int,soft_perc:int,len:int):Point
		{
			var px:Point = new Point();
			var perc_size:int = int((Number(soft_perc/100) * len));
			var _point:int = int((Number(soft_point/100) * len));
			var off:int = 0;

			px.x = int(_point - int(perc_size/2));

			off = 0;
			while(px.x < 0)
			{
				px.x = px.x + 1;
				off++;
			}

			px.y = px.x + ((_point + perc_size) - px.x);

			off = 0;
			while(px.y > len)
			{
				px.y = px.y - 1;
				off++;
			}

			px.x-=off;

			if(px.x < 0)
			{
				px.x = -1;
				px.y = -1;
				trace("file too small to handle this soft crypt");
			}
			
			return px;
		}


		private static function get_len8_dim(size:int):int
		{
			var len8:int;
			var padding_length:int = size % SIZE_UINT64;
			if (padding_length == 0) {
			  padding_length = SIZE_UINT64;
			} else {
			  padding_length = SIZE_UINT64 - padding_length;
			}
			len8 = size + padding_length;
			return len8;
		}

	}
	



}