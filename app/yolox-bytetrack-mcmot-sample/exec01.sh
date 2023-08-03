
#!/bin/bash
date
python3 sample.py --movie ./test.mp4 --width 1280 --height 720 --yolox_model model/yolox_s.onnx --input_shape 640,640
#python3 sample.py --movie ./20220922-1220.mp4 --width 1280 --height 720 --yolox_model model/yolox_s.onnx --input_shape 640,640
date
