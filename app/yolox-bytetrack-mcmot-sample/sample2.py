#!/usr/bin/env python
# -*- coding: utf-8 -*-
#import copy
import time

from ObjectDetector import MovieContext,ObjectDetector
from ObjectTracker import ObjectTracker
from VideoWriter import VideoWriter

def main():
    ## 引数解析 ##
    args = MovieContext().get_args()
    cap_device = args.device
    cap_width = args.width
    cap_height = args.height

    if args.movie is not None:
        cap_device = args.movie

    ## 物体検知のobject 生成
    detector = ObjectDetector(args)
    ## 動画出力 object 生成
    video_writer = VideoWriter(args, cap_device, cap_width, cap_height, detector.get_classes())
   
    cap_fps = video_writer.get_fps()

    ## トラッキング object 生成
    obj_tracker = ObjectTracker(args, cap_fps)

    while True:
        start_time = time.time()

        ## カメラキャプチャ ##
        ret, frame = video_writer.read_cap()
        if not ret:
            break
        #debug_image = copy.deepcopy(frame)

        # Object Detection
        bboxes, scores, class_ids = detector.infer(frame)

        # Multi Object Tracking
        t_ids, t_bboxes, t_scores, t_class_ids = obj_tracker.put(frame, bboxes, scores, class_ids)

        elapsed_time = time.time() - start_time

        # デバッグ描画
        debug_image = video_writer.draw_debug(
            frame,
            elapsed_time,
            detector.score_th,
            t_ids,
            t_bboxes,
            t_scores,
            t_class_ids,
            obj_tracker.track_id_dict,
            obj_tracker.track_id_frames
        )


    # トラッキングID単位の動画
    #video_writer.write_track_id_wise_video(
    #    obj_tracker.track_id_frames, 
    #    cap_fps)



if __name__ == '__main__':
    main()

