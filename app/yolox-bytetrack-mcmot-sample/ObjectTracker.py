#!/usr/bin/env python
# -*- coding: utf-8 -*-
from bytetrack.mc_bytetrack import MultiClassByteTrack

# トラッキングクラス
class ObjectTracker(object):
    def __init__(self, args, cap_fps):
        self.cap_fps = cap_fps

        # ByteTrack parameters
        self.track_thresh = args.track_thresh
        self.track_buffer = args.track_buffer
        self.match_thresh = args.match_thresh
        self.min_box_area = args.min_box_area
        self.mot20 = args.mot20


        # ByteTrackerインスタンス生成
        self.tracker = MultiClassByteTrack(
            fps=self.cap_fps,
            track_thresh=self.track_thresh,
            track_buffer=self.track_buffer,
            match_thresh=self.match_thresh,
            min_box_area=self.min_box_area,
            mot20=self.mot20,
        )

        # トラッキングID保持用変数
        self.track_id_dict = {}

        # トラッカー別のフレーム保持用
        self.track_id_frames = {}

    def put(self, frame, bboxes, scores, class_ids):
        # Multi Object Tracking
        t_ids, t_bboxes, t_scores, t_class_ids = self.tracker(
            frame,
            bboxes,
            scores,
            class_ids,
        )

        # トラッキングIDと連番の紐付け
        for trakcer_id, bbox in zip(t_ids, bboxes):
            if trakcer_id not in self.track_id_dict:
                new_id = len(self.track_id_dict)
                self.track_id_dict[trakcer_id] = new_id

        return t_ids, t_bboxes, t_scores, t_class_ids

