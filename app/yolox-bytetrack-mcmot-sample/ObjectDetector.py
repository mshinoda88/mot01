#!/usr/bin/env python
# -*- coding: utf-8 -*-
import argparse
from yolox.yolox_onnx import YoloxONNX

# パラメータ保持クラス
class MovieContext(object):
    def get_args(self):
        parser = argparse.ArgumentParser()

        parser.add_argument("--device", type=int, default=0)
        parser.add_argument("--movie", type=str, default=None)
        parser.add_argument("--width", help='cap width', type=int, default=960)
        parser.add_argument("--height", help='cap height', type=int, default=540)

        # YOLOX parameters
        parser.add_argument(
            "--yolox_model",
            type=str,
            default='model/yolox_nano.onnx',
        )
        parser.add_argument(
            '--input_shape',
            type=str,
            default="416,416",
            help="Specify an input shape for inference.",
        )
        parser.add_argument(
            '--score_th',
            type=float,
            default=0.3,
            help='Class confidence',
        )
        parser.add_argument(
            '--nms_th',
            type=float,
            default=0.45,
            help='NMS IoU threshold',
        )
        parser.add_argument(
            '--nms_score_th',
            type=float,
            default=0.1,
            help='NMS Score threshold',
        )
        parser.add_argument(
            "--with_p6",
            action="store_true",
            help="Whether your model uses p6 in FPN/PAN.",
        )

        # motpy parameters
        parser.add_argument(
            "--track_thresh",
            type=float,
            default=0.5,
        )
        parser.add_argument(
            "--track_buffer",
            type=int,
            default=30,
        )
        parser.add_argument(
            "--match_thresh",
            type=float,
            default=0.8,
        )
        parser.add_argument(
            "--min_box_area",
            type=int,
            default=10,
        )
        parser.add_argument(
            "--mot20",
            action="store_true",
        )

        args = parser.parse_args()
        return args


# 物体検知クラス
class ObjectDetector(object):
    def __init__(self, args):
        # YOLOX parameters
        self.model_path = args.yolox_model
        self.input_shape = tuple(map(int, args.input_shape.split(',')))
        self.score_th = args.score_th
        self.nms_th = args.nms_th
        self.nms_score_th = args.nms_score_th
        self.with_p6 = args.with_p6
        
        self.yolox = None

        # COCOクラスリスト読み込み
        with open('coco_classes.txt', 'rt') as f:
            self.coco_classes = f.read().rstrip('\n').split('\n')


    def _load_model(self):
        ## モデルロード ##
        if self.yolox is None:
            self.yolox = YoloxONNX(
                model_path=self.model_path,
                input_shape=self.input_shape,
                class_score_th=self.score_th,
                nms_th=self.nms_th,
                nms_score_th=self.nms_score_th,
                with_p6=self.with_p6,
                providers=['CPUExecutionProvider'],
             )
        return self.yolox


    def infer(self, frame):
        ## 推論実施 ##
        self.yolox = self._load_model()
        bboxes, scores, class_ids = self.yolox.inference(frame)
        return bboxes, scores, class_ids


    # coco データセットで認識する物体ID一覧
    def get_classes(self):
        return self.coco_classes

